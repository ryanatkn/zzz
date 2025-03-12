import {writeFileSync, rmSync} from 'node:fs';
import {ensure_end} from '@ryanatkn/belt/string.js';

/**
 * Checks if a path is within any of the allowed directories
 */
export const is_path_in_allowed_dirs = (path: string, dirs: ReadonlyArray<string>): boolean => {
	return dirs.some((dir) => path.startsWith(ensure_end(dir, '/')));
};

/**
 * Writes `contents` at `path` but only if it's inside one of the allowed dirs.
 */
export const write_diskfile_in_scope = (
	path: string,
	contents: string,
	dir: string | ReadonlyArray<string>,
): boolean => {
	const dirs = Array.isArray(dir) ? dir : [dir];

	if (!is_path_in_allowed_dirs(path, dirs)) {
		console.error(`refused to write file, path ${path} must be in one of dirs ${dirs.join(', ')}`);
		return false;
	}
	writeFileSync(path, contents, 'utf8');
	return true;
};

/**
 * Deletes the file at `path` but only if it's inside one of the allowed dirs.
 */
export const delete_diskfile_in_scope = (
	path: string,
	dir: string | ReadonlyArray<string>,
): boolean => {
	const dirs = Array.isArray(dir) ? dir : [dir];

	if (!is_path_in_allowed_dirs(path, dirs)) {
		console.error(`refused to delete file, path ${path} must be in one of dirs ${dirs.join(', ')}`);
		return false;
	}
	rmSync(path);
	return true;
};
