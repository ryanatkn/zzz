import {z} from 'zod';

import {Cell_Json} from '$lib/cell_types.js';
import {is_path_absolute} from '$lib/diskfile_helpers.js';
import {ensure_end} from '@ryanatkn/belt/string.js';

// Define file change types
export const Diskfile_Change_Type = z.enum(['add', 'change', 'delete']);
export type Diskfile_Change_Type = z.infer<typeof Diskfile_Change_Type>;

/** An absolute Unix-style file path */
export const Diskfile_Path = z
	.string()
	.transform((p) => p.trim())
	.refine((p) => is_path_absolute(p), {message: 'Path must be absolute'})
	.brand('Diskfile_Path');
export type Diskfile_Path = z.infer<typeof Diskfile_Path>;

/**
 * The Zzz server has a special filesystem directory that contains the app's data at `/.zzz`.
 * Zzz also provides an API for reading and writing to `.zzz`'s parent directory.
 *
 * This is a security-sensitive path that should be validated carefully.
 * See the `Safe_Fs` class for usage.
 *
 * Note the canonical path is `/path/to/zzz/.zzz/` with a trailing slash.
 */
export const Zzz_Dir = Diskfile_Path.refine((p) => p.endsWith('/.zzz'), {
	message: 'Path must end with /.zzz',
})
	.transform((p) => ensure_end(p, '/'))
	.brand('Zzz_Dir');
export type Zzz_Dir = z.infer<typeof Zzz_Dir>;

// Use a more specific definition for Maps compatible with Gro's Source_File
export const Source_File = z.object({
	id: Diskfile_Path,
	contents: z.string().nullable(),
	external: z.boolean(),
	ctime: z.number().nullable(),
	mtime: z.number().nullable(),
	// Using any for Map generics to avoid circular references
	// but still preserve the Map instance type
	dependents: z.instanceof(Map) as z.ZodType<Map<any, any>>,
	dependencies: z.instanceof(Map) as z.ZodType<Map<any, any>>,
});
export type Source_File = z.infer<typeof Source_File>;

// Directly extend the base schema with Diskfile-specific properties
export const Diskfile_Json = Cell_Json.extend({
	path: Diskfile_Path.nullable().default(null),
	content: z.string().nullable().default(null),
	external: z.boolean().default(false),
	dependents: z.array(z.tuple([Diskfile_Path, z.any()])).default(() => []),
	dependencies: z.array(z.tuple([Diskfile_Path, z.any()])).default(() => []),
});

export type Diskfile_Json = z.infer<typeof Diskfile_Json>;
