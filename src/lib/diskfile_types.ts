import {z} from 'zod';

import {Cell_Json} from '$lib/cell_types.js';
import {is_path_absolute} from '$lib/diskfile_helpers.js';
import {Path_With_Trailing_Slash} from '$lib/zod_helpers.js';

export const Diskfile_Change_Type = z.enum(['add', 'change', 'delete']);
export type Diskfile_Change_Type = z.infer<typeof Diskfile_Change_Type>;

/** An absolute Unix-style file path. */
export const Diskfile_Path = z
	.string()
	.refine((p) => is_path_absolute(p), {message: 'path must be absolute'})
	.brand('Diskfile_Path');
export type Diskfile_Path = z.infer<typeof Diskfile_Path>;

/** These always have a trailing slash. */
export const Diskfile_Directory_Path =
	Path_With_Trailing_Slash.pipe(Diskfile_Path).brand('Diskfile_Directory_Path');
export type Diskfile_Directory_Path = z.infer<typeof Diskfile_Directory_Path>;

export const Diskfile_Change = z.strictObject({
	type: Diskfile_Change_Type,
	path: Diskfile_Path,
});
export type Diskfile_Change = z.infer<typeof Diskfile_Change>;

// TODO hacky, uses the serializable form of the Gro `Disknode` (which uses maps)
export const Serializable_Disknode = z.strictObject({
	id: Diskfile_Path,
	source_dir: Diskfile_Directory_Path,
	contents: z.string().nullable(),
	ctime: z.number().nullable(),
	mtime: z.number().nullable(),
	dependents: z.array(z.tuple([Diskfile_Path, z.any()])), // TODO @many zod4 - these can't be circular refs, how to rewrite?
	dependencies: z.array(z.tuple([Diskfile_Path, z.any()])), // TODO @many zod4 - these can't be circular refs, how to rewrite?
});
export type Serializable_Disknode = z.infer<typeof Serializable_Disknode>;

// Directly extend the base schema with Diskfile-specific properties
export const Diskfile_Json = Cell_Json.extend({
	path: Diskfile_Path.nullable().default(null),
	source_dir: Diskfile_Directory_Path,
	content: z.string().nullable().default(null),
	dependents: z
		.array(z.tuple([Diskfile_Path, Serializable_Disknode]))
		.nullable()
		.default(null),
	dependencies: z
		.array(z.tuple([Diskfile_Path, Serializable_Disknode]))
		.nullable()
		.default(null),
}).meta({cell_class_name: 'Diskfile'});
export type Diskfile_Json = z.infer<typeof Diskfile_Json>;
export type Diskfile_Json_Input = z.input<typeof Diskfile_Json>;
