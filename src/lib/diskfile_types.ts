import {z} from 'zod';
import type {Watcher_Change_Type} from '@ryanatkn/gro/watch_dir.js';
import type {Source_File as Source_File_Type} from '@ryanatkn/gro/filer.js';

import {Datetime, Datetime_Now} from '$lib/zod_helpers.js';
import {Uuid} from '$lib/uuid.js';

// Define file change types
export const Diskfile_Change_Type = z.enum(['add', 'change', 'delete']);
export type Diskfile_Change_Type = z.infer<typeof Diskfile_Change_Type>;

// TODO ideally this shouldn't exist, right?
export const map_watcher_change_to_diskfile_change = (
	type: Watcher_Change_Type,
): Diskfile_Change_Type => {
	if (type === 'update') return 'change';
	return type as Diskfile_Change_Type;
};

export const Diskfile_Path = z.string().brand('Diskfile_Path');
export type Diskfile_Path = z.infer<typeof Diskfile_Path>;

// TODO upstream to Gro
export const Source_File = z.object({
	id: Diskfile_Path,
	contents: z.string().nullable(),
	external: z.boolean(),
	ctime: z.number().nullable(),
	mtime: z.number().nullable(),
	dependents: z.instanceof(Map),
	dependencies: z.instanceof(Map),
});
export type Source_File = z.infer<typeof Source_File>;

// TODO extract to type helpers
export const assert_valid_source_file = (source_file: Source_File_Type): Source_File => {
	return Source_File.parse({
		...source_file,
		id: source_file.id as Diskfile_Path,
	});
};

export const Diskfile_Json = z
	.object({
		id: Uuid,
		path: Diskfile_Path.nullable().default(null), // Renamed from file_id to path
		contents: z.string().nullable().default(null),
		external: z.boolean().default(false),
		created: Datetime_Now,
		updated: Datetime.nullable().default(null),
		dependents: z.array(z.tuple([Diskfile_Path, z.any()])).default(() => []),
		dependencies: z.array(z.tuple([Diskfile_Path, z.any()])).default(() => []),
	})
	.default(() => ({}));

export type Diskfile_Json = z.infer<typeof Diskfile_Json>;

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
