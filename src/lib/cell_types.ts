import {z} from 'zod';
import {Datetime, Datetime_Now, Uuid} from '$lib/zod_helpers.js';

/**
 * Get keys from a Zod schema object
 */
export type Schema_Keys<T extends z.ZodType> = keyof z.infer<T> & string;

/**
 * Get value type for a specific key in a Zod schema
 */
export type Schema_Value<T extends z.ZodType, K extends Schema_Keys<T>> = z.infer<T>[K];

/**
 * Base schema that defines common properties for all cells
 */
export const Cell_Json = z.object({
	id: Uuid,
	created: Datetime_Now,
	updated: Datetime.nullable().default(null),
});
export type Cell_Json = z.infer<typeof Cell_Json>;
