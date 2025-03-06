import type {Watcher_Change_Type} from '@ryanatkn/gro/watch_dir.js';

import {Uuid, Datetime, Datetime_Now} from '$lib/zod_helpers.js';
import {
	Diskfile_Change_Type,
	Diskfile_Path,
	Source_File,
	type Diskfile_Json,
} from '$lib/diskfile_types.js';

/**
 * Maps watcher change types to diskfile change types
 */
export const map_watcher_change_to_diskfile_change = (
	type: Watcher_Change_Type,
): Diskfile_Change_Type => {
	if (type === 'update') return 'change';
	return type as Diskfile_Change_Type;
};

/**
 * Helper function to convert a Source_File to Diskfile_Json format
 * @param source_file The source file to convert
 * @param existing_id Optional existing UUID to preserve ID stability across updates
 */
export const source_file_to_diskfile_json = (
	source_file: Source_File,
	existing_id?: Uuid,
): Diskfile_Json => {
	return {
		id: existing_id ?? Uuid.parse(undefined), // Use existing ID if provided, otherwise generate new
		path: source_file.id,
		contents: source_file.contents,
		external: source_file.external,
		created: Datetime_Now.parse(source_file.ctime && new Date(source_file.ctime).toISOString()), // TODO seems messy
		updated: source_file.mtime ? Datetime.parse(new Date(source_file.mtime).toISOString()) : null,
		dependents: Array.from(source_file.dependents.entries()).map(([id, s]) => [
			Diskfile_Path.parse(id),
			s,
		]),
		dependencies: Array.from(source_file.dependencies.entries()).map(([id, s]) => [
			Diskfile_Path.parse(id),
			s,
		]),
	};
};
