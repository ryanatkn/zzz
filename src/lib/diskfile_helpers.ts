import type {Watcher_Change_Type} from '@ryanatkn/gro/watch_dir.js';
import type {Disknode} from '@ryanatkn/gro/disknode.js';
import {strip_start} from '@ryanatkn/belt/string.js';

import {Uuid, Datetime, Datetime_Now, create_uuid} from '$lib/zod_helpers.js';
import {
	Diskfile_Change_Type,
	Diskfile_Directory_Path,
	Diskfile_Path,
	Serializable_Disknode,
	type Diskfile_Json,
} from '$lib/diskfile_types.js';
import type {Diskfile} from '$lib/diskfile.svelte.js';

// TODO probably extract to `@ryanatkn/belt/path.js`
export const is_path_absolute = (path: string): boolean => path[0] === '/';

// TODO hacky, refactor path helpers with `@ryanatkn/belt/path.js`
export const to_relative_path = (path: string, parent: string): string =>
	strip_start(strip_start(path, parent), '/');

/**
 * Maps watcher change types to diskfile change types
 */
export const map_watcher_change_to_diskfile_change = (
	type: Watcher_Change_Type,
): Diskfile_Change_Type => {
	if (type === 'update') return 'change';
	return type as Diskfile_Change_Type;
};

// TODO @many refactor source/disk files with Gro Disknode too
/**
 * Helper function to convert a `Serializable_Disknode` to the `Diskfile_Json` format.
 * @param disknode The source file to convert
 * @param existing_id Optional existing UUID to preserve id stability across updates
 */
export const disknode_to_diskfile_json = (
	disknode: Serializable_Disknode,
	existing_id: Uuid = create_uuid(),
): Diskfile_Json => {
	const created = Datetime_Now.parse(
		disknode.ctime == null ? undefined : new Date(disknode.ctime).toISOString(),
	);
	return {
		id: existing_id,
		source_dir: disknode.source_dir,
		path: disknode.id, // notice the Disknode `id` is a path
		content: disknode.contents, // notice `contents` -> `content`
		created,
		updated:
			disknode.mtime == null ? created : Datetime.parse(new Date(disknode.mtime).toISOString()),
		dependents: disknode.dependents,
		dependencies: disknode.dependencies,
	};
};

// TODO hacky
export const SUPPORTED_CODE_FILETYPE_MATCHER = /\.[mc]?[jt]sx?$/i;
export const has_dependencies = (diskfile: Diskfile): boolean =>
	diskfile.dependencies_count > 0 ||
	diskfile.dependents_count > 0 ||
	SUPPORTED_CODE_FILETYPE_MATCHER.test(diskfile.path);

// TODO @many refactor source/disk files with Gro Disknode too
export const to_serializable_disknode = (
	disknode: Disknode,
	dir: string,
): Serializable_Disknode => ({
	id: disknode.id as Diskfile_Path,
	source_dir: dir as Diskfile_Directory_Path,
	contents: disknode.contents,
	ctime: disknode.ctime,
	mtime: disknode.mtime,
	dependents: Array.from(disknode.dependents.entries()) as Serializable_Disknode['dependents'],
	dependencies: Array.from(
		disknode.dependencies.entries(),
	) as Serializable_Disknode['dependencies'],
}); // TODO @many refactor source/disk files with Gro Disknode too
