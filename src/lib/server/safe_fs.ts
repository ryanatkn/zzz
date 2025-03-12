import * as fs from 'node:fs/promises';
import type * as fs_types from 'node:fs';
import {existsSync} from 'node:fs';
import {dirname, normalize} from 'node:path';
import {ensure_end} from '@ryanatkn/belt/string.js';
import {z} from 'zod';

/**
 * A branded type for representing safely normalized filesystem paths
 */
export const Safe_Fs_Path = z
	.string()
	.refine((p) => p.startsWith('/'), {
		message: 'Path must be absolute',
	})
	.transform((p) => normalize(p)) // Normalize the path to resolve any `.` or `..` segments and collapse multiple slashes
	.brand('Safe_Fs_Path');

export type Safe_Fs_Path = z.infer<typeof Safe_Fs_Path>;

export class Safe_Fs {
	readonly #allowed_paths: ReadonlyArray<Safe_Fs_Path>;

	/**
	 * Create a new Safe_Fs instance with the specified allowed paths.
	 * @param allowed_paths Array of absolute paths that operations will be restricted to
	 */
	constructor(allowed_paths: Array<string> | ReadonlyArray<string>) {
		// Parse each path as a Safe_Fs_Path and freeze the array to ensure immutability
		try {
			this.#allowed_paths = Object.freeze(
				allowed_paths.filter(Boolean).map((p) => {
					// Ensure path is absolute
					if (!p.startsWith('/')) {
						throw new Path_Not_Allowed_Error(p);
					}
					// Parse with Safe_Fs_Path schema to get normalized branded type
					return Safe_Fs_Path.parse(p);
				}),
			);
		} catch (error) {
			if (error instanceof z.ZodError) {
				throw new Error(`Invalid path in allowed_paths: ${error.message}`);
			}
			throw error;
		}
	}

	/**
	 * Checks if the given path is allowed based on the paths provided during instantiation
	 */
	is_path_allowed(path_to_check: string): boolean {
		if (!path_to_check) return false;
		if (!path_to_check.startsWith('/')) return false;

		// First check for path traversal attempts
		if (this.#has_traversal_segments(path_to_check)) {
			return false;
		}

		// Try to parse as Safe_Fs_Path, return false if it fails
		try {
			// This will normalize the path
			Safe_Fs_Path.parse(path_to_check);
		} catch {
			return false;
		}

		return this.#validate_safe_path(path_to_check) !== null;
	}

	/**
	 * Read a file if it's in an allowed path
	 */
	async read_file(
		file_path: string,
		options?: Parameters<typeof fs.readFile>[1],
	): Promise<Buffer | string> {
		const safe_path = await this.#ensure_safe_path(file_path);
		return fs.readFile(safe_path, options);
	}

	/**
	 * Write to a file if it's in an allowed path
	 */
	async write_file(
		file_path: string,
		data: string | NodeJS.ArrayBufferView,
		options?: fs_types.WriteFileOptions | null,
	): Promise<void> {
		const safe_path = await this.#ensure_safe_path(file_path);
		return fs.writeFile(safe_path, data, options ?? null);
	}

	/**
	 * Delete a file if it's in an allowed path
	 */
	async unlink(file_path: string): Promise<void> {
		const safe_path = await this.#ensure_safe_path(file_path);
		return fs.unlink(safe_path);
	}

	/**
	 * Remove a file or directory if it's in an allowed path
	 */
	async rm(path_to_remove: string, options?: fs_types.RmOptions): Promise<void> {
		const safe_path = await this.#ensure_safe_path(path_to_remove);
		return fs.rm(safe_path, options);
	}

	/**
	 * Create a directory if it's in an allowed path
	 */
	async mkdir(
		dir_path: string,
		options?: fs_types.MakeDirectoryOptions,
	): Promise<string | undefined> {
		const safe_path = await this.#ensure_safe_path(dir_path);
		return fs.mkdir(safe_path, options);
	}

	/**
	 * Remove a directory if it's in an allowed path
	 */
	async rmdir(dir_path: string, options?: fs_types.RmDirOptions): Promise<void> {
		const safe_path = await this.#ensure_safe_path(dir_path);
		return fs.rmdir(safe_path, options);
	}

	// TODO this does not include all of the possible signatures for readdir
	/**
	 * List directory contents if it's in an allowed path
	 */
	async readdir(
		path: fs_types.PathLike,
		options?:
			| (fs_types.ObjectEncodingOptions & {
					withFileTypes?: false | undefined;
					recursive?: boolean | undefined;
			  })
			| BufferEncoding
			| null,
	): Promise<Array<string>>;
	async readdir(
		path: fs_types.PathLike,
		options: fs_types.ObjectEncodingOptions & {
			withFileTypes: true;
			recursive?: boolean | undefined;
		},
	): Promise<Array<fs_types.Dirent>>;
	async readdir(
		dir_path: string,
		options?: fs_types.ObjectEncodingOptions | BufferEncoding | null,
	): Promise<Array<fs_types.Dirent> | Array<string>> {
		const safe_path = await this.#ensure_safe_path(dir_path);
		return fs.readdir(safe_path, options);
	}

	/**
	 * Get file stats if it's in an allowed path
	 */
	async stat(path_to_stat: string, options?: fs_types.StatOptions): Promise<fs_types.Stats> {
		const safe_path = await this.#ensure_safe_path(path_to_stat);
		return fs.stat(safe_path, {...options, bigint: false});
	}

	/**
	 * Get file or symlink stats if it's in an allowed path
	 */
	async lstat(path_to_stat: string, options?: fs_types.StatOptions): Promise<fs_types.Stats> {
		const safe_path = await this.#ensure_safe_path(path_to_stat);
		const stats = await fs.lstat(safe_path, {...options, bigint: false});
		return stats;
	}

	/**
	 * Copy a file if both source and destination are in allowed paths
	 */
	async copyFile(source: string, destination: string, mode?: number): Promise<void> {
		const safe_source = await this.#ensure_safe_path(source);
		const safe_destination = await this.#ensure_safe_path(destination);
		return fs.copyFile(safe_source, safe_destination, mode);
	}

	/**
	 * Check if a path exists and is in an allowed directory
	 */
	async exists(path_to_check: string): Promise<boolean> {
		try {
			if (!this.is_path_allowed(path_to_check)) {
				return false;
			}

			await fs.access(path_to_check);
			return true;
		} catch {
			return false;
		}
	}

	/**
	 * Check if a path is a directory and is in an allowed directory
	 */
	async is_directory(path_to_check: string): Promise<boolean> {
		try {
			if (!this.is_path_allowed(path_to_check)) {
				return false;
			}

			// Get the stats directly without additional validation
			// since we already checked the path is allowed
			const stats = await fs.lstat(path_to_check);
			return stats.isDirectory();
		} catch {
			return false;
		}
	}

	/**
	 * Check if a path is a file and is in an allowed directory
	 */
	async is_file(path_to_check: string): Promise<boolean> {
		try {
			if (!this.is_path_allowed(path_to_check)) {
				return false;
			}

			// Get the stats directly without additional validation
			const stats = await fs.lstat(path_to_check);
			return stats.isFile();
		} catch {
			return false;
		}
	}

	/**
	 * Check if a path is a symlink
	 */
	async is_symlink(path_to_check: string): Promise<boolean> {
		try {
			// Only validate path is allowed without checking parents for symlinks
			if (!this.is_path_allowed(path_to_check)) {
				return false;
			}

			// Simple symlink check
			if (existsSync(path_to_check)) {
				const stats = await fs.lstat(path_to_check);
				return stats.isSymbolicLink();
			}
			return false;
		} catch {
			return false;
		}
	}

	/**
	 * Validates if a path is within allowed directories.
	 * Returns the matching allowed path if valid, null otherwise.
	 */
	#validate_safe_path(path_to_check: string): Safe_Fs_Path | null {
		if (!path_to_check) return null;

		// Check for path traversal attempts (.. segments)
		if (this.#has_traversal_segments(path_to_check)) {
			return null;
		}

		try {
			// Normalize the path before comparison
			const normalized_path = Safe_Fs_Path.parse(path_to_check);

			// Check if the path is within any allowed directory
			for (const allowed_path of this.#allowed_paths) {
				if (!allowed_path) continue;

				// Handle special case for root directory
				if (allowed_path === '/') {
					if (normalized_path.startsWith('/')) {
						return allowed_path;
					}
					continue;
				}

				// Direct path match
				if (normalized_path === allowed_path) return allowed_path;

				// Path is inside the directory (with trailing slash)
				const dir_with_sep = ensure_end(allowed_path, '/');
				if (normalized_path.startsWith(dir_with_sep)) return allowed_path;

				// Handle directory with trailing slash matching path without
				if (allowed_path.endsWith('/') && normalized_path === allowed_path.slice(0, -1)) {
					return allowed_path;
				}

				// Handle directory without trailing slash
				if (!allowed_path.endsWith('/')) {
					if (normalized_path === allowed_path || normalized_path.startsWith(allowed_path + '/')) {
						return allowed_path;
					}
				}
			}
		} catch {
			// If path normalization fails, the path is invalid
			return null;
		}

		return null;
	}

	/**
	 * Ensures a path is safe by validating it.
	 * Throws an error if the path is not allowed.
	 */
	async #ensure_safe_path(path_to_check: string): Promise<string> {
		// Early rejection if path is not absolute
		if (!path_to_check.startsWith('/')) {
			throw new Path_Not_Allowed_Error(path_to_check);
		}

		let normalized_path: Safe_Fs_Path;
		try {
			// Normalize the path before validation
			normalized_path = Safe_Fs_Path.parse(path_to_check);
		} catch (_error) {
			// If normalization fails, the path is not allowed
			throw new Path_Not_Allowed_Error(path_to_check);
		}

		const validated = this.#validate_safe_path(normalized_path);
		if (validated === null) {
			throw new Path_Not_Allowed_Error(normalized_path);
		}

		// Check path itself first if it exists
		if (existsSync(normalized_path)) {
			try {
				const stats = await fs.lstat(normalized_path);
				if (stats.isSymbolicLink()) {
					throw new Symlink_Not_Allowed_Error(normalized_path);
				}
			} catch (error) {
				// If error is about the path being a symlink, rethrow
				if (error instanceof Symlink_Not_Allowed_Error) {
					throw error;
				}
				// For other errors (like permission issues), we'll check parent dirs
			}
		}

		// Check each parent directory for symlinks
		let current: string = normalized_path;
		while (current !== '/' && current !== '.') {
			const parent = dirname(current);
			if (parent === current) break; // Reached root

			if (existsSync(parent)) {
				try {
					const stats = await fs.lstat(parent); // eslint-disable-line no-await-in-loop
					if (stats.isSymbolicLink()) {
						throw new Symlink_Not_Allowed_Error(parent);
					}
				} catch (error) {
					// If error is about the path being a symlink, rethrow
					if (error instanceof Symlink_Not_Allowed_Error) {
						throw error;
					}
					// For other errors, continue checking parent dirs
				}
			}

			current = parent;
		}

		return normalized_path;
	}

	/**
	 * Checks if a path contains traversal segments (..)
	 */
	#has_traversal_segments(path_to_check: string): boolean {
		// Check for URL-style paths which should not be allowed
		if (
			path_to_check.startsWith('file://') ||
			path_to_check.startsWith('http://') ||
			path_to_check.startsWith('https://')
		) {
			return true;
		}

		// Reject relative paths
		if (!path_to_check.startsWith('/')) {
			return true;
		}

		// Direct string check for common traversal patterns
		if (path_to_check === '..') return true;
		if (path_to_check === '.') return true;

		// Check for '../' or '/..' patterns which indicate directory traversal
		if (path_to_check.includes('../') || path_to_check.includes('/..')) {
			return true;
		}

		// Check for './' patterns
		if (path_to_check.includes('./')) {
			return true;
		}

		// For Windows compatibility
		if (path_to_check.includes('..\\') || path_to_check.includes('\\..')) {
			return true;
		}

		return false;
	}
}

/**
 * Error thrown when a path is not allowed
 */
export class Path_Not_Allowed_Error extends Error {
	override name = 'Path_Not_Allowed_Error' as const;

	constructor(path: string) {
		super(`Path is not allowed: ${path}`);
	}
}

/**
 * Error thrown when a path is a symlink
 */
export class Symlink_Not_Allowed_Error extends Error {
	override name = 'Symlink_Not_Allowed_Error' as const;

	constructor(path: string) {
		super(`Path is a symlink which is not allowed: ${path}`);
	}
}
