import type {Watcher_Change_Type} from '@ryanatkn/gro/watch_dir.js';
import type {Source_File as Source_File_Type} from '@ryanatkn/gro/filer.js';

import {Datetime, Datetime_Now} from '$lib/zod_helpers.js';
import {Uuid} from '$lib/zod_helpers.js';
import {
	Diskfile_Change_Type,
	Diskfile_Path,
	Source_File,
	type Diskfile_Json,
} from '$lib/diskfile_types.js';

// TODO ideally this shouldn't exist, right?
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
 * Validates and converts a source file to the internal Source_File type
 */
export const assert_valid_source_file = (source_file: Source_File_Type): Source_File => {
	return Source_File.parse({
		...source_file,
		id: source_file.id as Diskfile_Path,
	});
};

/**
 * Helper function to convert a Source_File to Diskfile_Json format
 */
export const source_file_to_diskfile_json = (source_file: Source_File_Type): Diskfile_Json => {
	return {
		id: Uuid.parse(undefined), // Generate a new UUID
		path: Diskfile_Path.parse(source_file.id),
		contents: source_file.contents,
		external: source_file.external,
		created: Datetime_Now.parse(undefined),
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
