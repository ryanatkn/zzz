import {z} from 'zod';

import {Cell_Json} from '$lib/cell_types.js';
import {is_path_absolute} from '$lib/diskfile_helpers.js';
import {Path_With_Trailing_Slash} from '$lib/zod_helpers.js';

export const Diskfile_Change_Type = z.enum(['add', 'change', 'delete']);
export type Diskfile_Change_Type = z.infer<typeof Diskfile_Change_Type>;

/** An absolute Unix-style file path. */
export const Diskfile_Path = z
	.string()
	.refine((p) => is_path_absolute(p), {message: 'Path must be absolute'})
	.brand('Diskfile_Path');
export type Diskfile_Path = z.infer<typeof Diskfile_Path>;

export const Diskfile_Change = z
	.object({
		type: Diskfile_Change_Type,
		path: Diskfile_Path,
	})
	.strict();
export type Diskfile_Change = z.infer<typeof Diskfile_Change>;

/**
 * The Zzz server has a special filesystem directory that contains the app's data at `/.zzz`.
 * Zzz also provides an API for reading and writing to `.zzz`'s parent directory.
 *
 * This is a security-sensitive path that should be validated carefully.
 * See the `Safe_Fs` class for usage.
 */
export const Zzz_Dir = Diskfile_Path.brand('Zzz_Dir');
export type Zzz_Dir = z.infer<typeof Zzz_Dir>;

// TODO hacky, uses the serializable form of the Gro `Source_File` (which uses maps)
export const Serializable_Source_File = z.object({
	id: Diskfile_Path,
	source_dir: Diskfile_Path.pipe(Path_With_Trailing_Slash),
	contents: z.string().nullable(),
	ctime: z.number().nullable(),
	mtime: z.number().nullable(),
	dependents: z.array(z.tuple([Diskfile_Path, z.any()])), // TODO @many zod4 - these can't be circular refs, how to rewrite?
	dependencies: z.array(z.tuple([Diskfile_Path, z.any()])), // TODO @many zod4 - these can't be circular refs, how to rewrite?
});
export type Serializable_Source_File = z.infer<typeof Serializable_Source_File>;

// Directly extend the base schema with Diskfile-specific properties
export const Diskfile_Json = Cell_Json.extend({
	path: Diskfile_Path.nullable().default(null),
	source_dir: Diskfile_Path.pipe(Path_With_Trailing_Slash),
	content: z.string().nullable().default(null),
	dependents: z
		.array(z.tuple([Diskfile_Path, Serializable_Source_File]))
		.nullable()
		.default(null),
	dependencies: z
		.array(z.tuple([Diskfile_Path, Serializable_Source_File]))
		.nullable()
		.default(null),
});
export type Diskfile_Json = z.infer<typeof Diskfile_Json>;
export type Diskfile_Json_Input = z.input<typeof Diskfile_Json>;
