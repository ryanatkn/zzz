import {z} from 'zod';

import {Datetime, Datetime_Now, Uuid} from '$lib/zod_helpers.js';

// Define file change types
export const Diskfile_Change_Type = z.enum(['add', 'change', 'delete']);
export type Diskfile_Change_Type = z.infer<typeof Diskfile_Change_Type>;

export const Diskfile_Path = z.string().brand('Diskfile_Path');
export type Diskfile_Path = z.infer<typeof Diskfile_Path>;

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

export const Diskfile_Json = z.object({
	id: Uuid,
	path: Diskfile_Path.nullable().default(null), // Renamed from file_id to path
	contents: z.string().nullable().default(null),
	external: z.boolean().default(false),
	created: Datetime_Now,
	updated: Datetime.nullable().default(null),
	dependents: z.array(z.tuple([Diskfile_Path, z.any()])).default(() => []),
	dependencies: z.array(z.tuple([Diskfile_Path, z.any()])).default(() => []),
});

export type Diskfile_Json = z.infer<typeof Diskfile_Json>;
