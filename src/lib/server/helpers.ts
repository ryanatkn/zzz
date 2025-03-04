import {writeFileSync, rmSync} from 'node:fs';
import type {Path_Id} from '@ryanatkn/gro/path.js';
import {ensure_end} from '@ryanatkn/belt/string.js';

/**
 * Writes `contents` at `id` but only if it's inside `dir`.
 */
export const write_file_in_scope = (id: Path_Id, contents: string, dir: string): boolean => {
	if (!id.startsWith(ensure_end(dir, '/'))) {
		console.error(`refused to write file, path ${id} must be in dir ${dir}`);
		return false;
	}
	writeFileSync(id, contents, 'utf8');
	return true;
};

/**
 * Deletes the file at `id` but only if it's inside `dir`.
 */
export const delete_diskfile_in_scope = (id: Path_Id, dir: string): boolean => {
	if (!id.startsWith(ensure_end(dir, '/'))) {
		console.error(`refused to delete file, path ${id} must be in dir ${dir}`);
		return false;
	}
	rmSync(id);
	return true;
};
