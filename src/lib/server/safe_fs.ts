import * as fs from 'node:fs/promises';
import type * as fs_types from 'node:fs';
import {existsSync} from 'node:fs';
import * as path from 'node:path';
import {ensure_end} from '@ryanatkn/belt/string.js';
import {z} from 'zod';

import {Diskfile_Path, Zzz_Dir} from '$lib/diskfile_types.js';

export class Safe_Fs {
	readonly #allowed_paths: ReadonlyArray<Zzz_Dir>;

	/**
	 * Create a new Safe_Fs instance with the specified allowed paths.
	 * @param allowed_paths Array of absolute paths that operations will be restricted to
	 */
	constructor(allowed_paths: Array<string> | ReadonlyArray<Zzz_Dir>) {
		// Parse each path as a Zzz_Dir and freeze the array to ensure immutability
		try {
			this.#allowed_paths = Object.freeze(
				allowed_paths.filter(Boolean).map((p) => {
					// Ensure path is absolute
					if (!p.startsWith('/')) {
						throw new Path_Not_Allowed_Error(p);
					}
					// Parse with Zzz_Dir schema to get branded type
					return Zzz_Dir.parse(p);
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

		// Try to parse as Diskfile_Path, return false if it fails
		try {
			Diskfile_Path.parse(path_to_check);
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
	async copyFile(source: string, destination: string, mode?: number | null): Promise<void> {
		const safe_source = await this.#ensure_safe_path(source);
		const safe_destination = await this.#ensure_safe_path(destination);
		return fs.copyFile(safe_source, safe_destination, mode || 0);
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
	#validate_safe_path(path_to_check: string): Zzz_Dir | null {
		if (!path_to_check) return null;

		// Check for path traversal attempts (.. segments)
		if (this.#has_traversal_segments(path_to_check)) {
			return null;
		}

		// Check if the path is within any allowed directory
		for (const allowed_path of this.#allowed_paths) {
			if (!allowed_path) continue;

			// Handle special case for root directory
			if (allowed_path === '/') {
				if (path_to_check.startsWith('/')) {
					return allowed_path;
				}
				continue;
			}

			// Direct path match
			if (path_to_check === allowed_path) return allowed_path;

			// Path is inside the directory (with trailing slash)
			const dir_with_sep = ensure_end(allowed_path, '/');
			if (path_to_check.startsWith(dir_with_sep)) return allowed_path;

			// Handle directory with trailing slash matching path without
			if (allowed_path.endsWith('/') && path_to_check === allowed_path.slice(0, -1)) {
				return allowed_path;
			}

			// Handle directory without trailing slash
			if (!allowed_path.endsWith('/')) {
				if (path_to_check === allowed_path || path_to_check.startsWith(allowed_path + '/')) {
					return allowed_path;
				}
			}
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

		try {
			// Try to parse the path with Diskfile_Path schema
			Diskfile_Path.parse(path_to_check);
		} catch {
			throw new Path_Not_Allowed_Error(path_to_check);
		}

		const validated = this.#validate_safe_path(path_to_check);
		if (validated === null) {
			throw new Path_Not_Allowed_Error(path_to_check);
		}

		// Check path itself first if it exists
		if (existsSync(path_to_check)) {
			try {
				const stats = await fs.lstat(path_to_check);
				if (stats.isSymbolicLink()) {
					throw new Symlink_Not_Allowed_Error(path_to_check);
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
		let current = path_to_check;
		while (current !== '/' && current !== '.') {
			const parent = path.dirname(current);
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

		return path_to_check;
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
