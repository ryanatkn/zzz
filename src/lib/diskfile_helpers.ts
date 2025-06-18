import type {Watcher_Change_Type} from '@ryanatkn/gro/watch_dir.js';
import type {Source_File} from '@ryanatkn/gro/filer.js';

import {Uuid, Datetime, Datetime_Now, create_uuid} from '$lib/zod_helpers.js';
import {
	Diskfile_Change_Type,
	Diskfile_Path,
	Serializable_Source_File,
	Zzz_Dir,
	type Diskfile_Json,
} from '$lib/diskfile_types.js';
import type {Diskfile} from '$lib/diskfile.svelte.js';
import {ZZZ_CACHE_DIRNAME} from '$lib/constants.js';

export const to_zzz_cache_dir = (
	dir: Zzz_Dir,
	dirname: string = ZZZ_CACHE_DIRNAME,
): Diskfile_Path => Diskfile_Path.parse(dir + dirname);

// TODO probably extract to `@ryanatkn/belt/path.js`
export const is_path_absolute = (path: string): boolean => path[0] === '/';

/**
 * Maps watcher change types to diskfile change types
 */
export const map_watcher_change_to_diskfile_change = (
	type: Watcher_Change_Type,
): Diskfile_Change_Type => {
	if (type === 'update') return 'change';
	return type as Diskfile_Change_Type;
};

// TODO @many refactor source/disk files with Gro Source_File too
/**
 * Helper function to convert a `Serializable_Source_File` to the `Diskfile_Json` format.
 * @param source_file The source file to convert
 * @param existing_id Optional existing UUID to preserve id stability across updates
 */
export const source_file_to_diskfile_json = (
	source_file: Serializable_Source_File,
	existing_id: Uuid = create_uuid(),
): Diskfile_Json => {
	const created = Datetime_Now.parse(
		source_file.ctime == null ? undefined : new Date(source_file.ctime).toISOString(),
	);
	return {
		id: existing_id,
		source_dir: source_file.source_dir,
		path: source_file.id, // notice the Source_File `id` is a path
		content: source_file.contents, // notice `contents` -> `content`
		created,
		updated:
			source_file.mtime == null
				? created
				: Datetime.parse(new Date(source_file.mtime).toISOString()),
		dependents: source_file.dependents,
		dependencies: source_file.dependencies,
	};
};

// TODO hacky
export const SUPPORTED_CODE_FILETYPE_MATCHER = /\.[mc]?[jt]sx?$/i;
export const has_dependencies = (diskfile: Diskfile): boolean =>
	diskfile.dependencies_count > 0 ||
	diskfile.dependents_count > 0 ||
	SUPPORTED_CODE_FILETYPE_MATCHER.test(diskfile.path);

// TODO @many refactor source/disk files with Gro Source_File too
export const to_serializable_source_file = (
	source_file: Source_File,
	dir: string,
): Serializable_Source_File => ({
	id: source_file.id as Diskfile_Path,
	source_dir: dir as Diskfile_Path,
	contents: source_file.contents,
	ctime: source_file.ctime,
	mtime: source_file.mtime,
	dependents: Array.from(
		source_file.dependents.entries(),
	) as Serializable_Source_File['dependents'],
	dependencies: Array.from(
		source_file.dependencies.entries(),
	) as Serializable_Source_File['dependencies'],
}); // TODO @many refactor source/disk files with Gro Source_File too
