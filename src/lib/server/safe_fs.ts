import * as fs from 'node:fs/promises';
import type * as fs_types from 'node:fs';
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
	.transform((p) => normalize(p))
	.brand('Safe_Fs_Path');

export type Safe_Fs_Path = z.infer<typeof Safe_Fs_Path>;

export class Safe_Fs {
	readonly #allowed_paths: ReadonlyArray<Safe_Fs_Path>;

	/**
	 * Create a new Safe_Fs instance with the specified allowed paths.
	 * @param allowed_paths Array of absolute paths that operations will be restricted to
	 */
	constructor(allowed_paths: Array<string> | ReadonlyArray<string>) {
		try {
			this.#allowed_paths = Object.freeze(
				allowed_paths.filter(Boolean).map((p) => Safe_Fs_Path.parse(p)),
			);
		} catch (error) {
			if (error instanceof z.ZodError) {
				throw new Error(`Invalid path in allowed_paths: ${error.message}`);
			}
			throw error;
		}
	}

	/**
	 * Checks if the given path is allowed based on the paths provided during instantiation.
	 */
	is_path_allowed(path_to_check: string): boolean {
		if (!path_to_check) return false;

		try {
			// Let the parser normalize and validate - this handles absolute path requirement
			// and normalizes all path traversal attempts
			const normalized_path = Safe_Fs_Path.parse(path_to_check);

			// Check if within allowed paths
			for (const allowed_path of this.#allowed_paths) {
				if (!allowed_path) continue;

				// Root directory is special
				if (allowed_path === '/' && normalized_path.startsWith('/')) {
					return true;
				}

				// Direct path match
				if (normalized_path === allowed_path) return true;

				// Path is inside with trailing slash
				const dir_with_sep = ensure_end(allowed_path, '/');
				if (normalized_path.startsWith(dir_with_sep)) return true;

				// Handle directory with trailing slash matching path without
				if (allowed_path.endsWith('/') && normalized_path === allowed_path.slice(0, -1)) {
					return true;
				}

				// Handle directory without trailing slash
				if (
					!allowed_path.endsWith('/') &&
					(normalized_path === allowed_path || normalized_path.startsWith(allowed_path + '/'))
				) {
					return true;
				}
			}
			return false;
		} catch {
			return false;
		}
	}

	/**
	 * Performs a complete security check on a path, including symlink validation
	 */
	async is_path_safe(path_to_check: string): Promise<boolean> {
		try {
			await this.#ensure_safe_path(path_to_check);
			return true;
		} catch {
			return false;
		}
	}

	async read_file(
		file_path: string,
		options?: Parameters<typeof fs.readFile>[1],
	): Promise<Buffer | string> {
		const safe_path = await this.#ensure_safe_path(file_path);
		return fs.readFile(safe_path, options);
	}

	async write_file(
		file_path: string,
		data: string | NodeJS.ArrayBufferView,
		options?: fs_types.WriteFileOptions | null,
	): Promise<void> {
		const safe_path = await this.#ensure_safe_path(file_path);
		return fs.writeFile(safe_path, data, options ?? null);
	}

	async unlink(file_path: string): Promise<void> {
		// Note: We're keeping unlink for consistency with Node's fs API
		// even though we don't allow operating on symlinks specifically
		const safe_path = await this.#ensure_safe_path(file_path);
		return fs.unlink(safe_path);
	}

	async rm(path_to_remove: string, options?: fs_types.RmOptions): Promise<void> {
		const safe_path = await this.#ensure_safe_path(path_to_remove);
		return fs.rm(safe_path, options);
	}

	async mkdir(
		dir_path: string,
		options?: fs_types.MakeDirectoryOptions,
	): Promise<string | undefined> {
		const safe_path = await this.#ensure_safe_path(dir_path);
		return fs.mkdir(safe_path, options);
	}

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

	async stat(
		path_to_stat: string,
		options?: fs_types.StatOptions & {
			bigint?: false | undefined;
		},
	): Promise<fs_types.Stats>;
	async stat(
		path_to_stat: string,
		options: fs_types.StatOptions & {
			bigint: true;
		},
	): Promise<fs_types.BigIntStats>;
	async stat(
		path_to_stat: string,
		options?: fs_types.StatOptions,
	): Promise<fs_types.Stats | fs_types.BigIntStats> {
		const safe_path = await this.#ensure_safe_path(path_to_stat);
		return fs.stat(safe_path, options);
	}

	async copy_file(source: string, destination: string, mode?: number): Promise<void> {
		const safe_source = await this.#ensure_safe_path(source);
		const safe_destination = await this.#ensure_safe_path(destination);
		return fs.copyFile(safe_source, safe_destination, mode);
	}

	async exists(path_to_check: string): Promise<boolean> {
		// Instead of throwing for disallowed paths, simply return false.
		if (!this.is_path_allowed(path_to_check)) {
			return false;
		}
		try {
			await this.#ensure_safe_path(path_to_check);
			await fs.access(Safe_Fs_Path.parse(path_to_check));
			return true;
		} catch {
			return false;
		}
	}

	/**
	 * Ensures a path is safe by validating it.
	 * Throws an error if the path is not allowed or contains symlinks.
	 */
	async #ensure_safe_path(path_to_check: string): Promise<string> {
		let normalized_path: Safe_Fs_Path;
		try {
			normalized_path = Safe_Fs_Path.parse(path_to_check);
		} catch {
			throw new Path_Not_Allowed_Error(path_to_check);
		}

		if (!this.is_path_allowed(normalized_path)) {
			throw new Path_Not_Allowed_Error(normalized_path);
		}

		// Check the target path if it exists
		try {
			const stats = await fs.lstat(normalized_path);
			if (stats.isSymbolicLink()) {
				throw new Symlink_Not_Allowed_Error(normalized_path);
			}
		} catch (err) {
			// If error is due to non-existence, ignore
			if (!(err instanceof Error && err.message.includes('ENOENT'))) {
				throw err;
			}
		}

		// Check all parent directories
		let current: string = normalized_path;
		while (current !== '/' && current !== '.') {
			const parent = dirname(current);
			if (parent === current) break;

			try {
				const stats = await fs.lstat(parent);
				if (stats.isSymbolicLink()) {
					throw new Symlink_Not_Allowed_Error(parent);
				}
			} catch (err) {
				if (!(err instanceof Error && err.message.includes('ENOENT'))) {
					throw err;
				}
			}
			current = parent;
		}
		return normalized_path;
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
