import {z} from 'zod';
import {Datetime_Now, Uuid_With_Default} from '$lib/zod_helpers.js';

/**
 * Get keys from a Zod schema object.
 */
export type Schema_Keys<T extends z.ZodType> = keyof z.infer<T> & string;

/**
 * Get value type for a specific key in a Zod schema.
 */
export type Schema_Value<T extends z.ZodType, K extends Schema_Keys<T>> = z.infer<T>[K];

/**
 * Base schema that defines common properties for all cells.
 */
export const Cell_Json = z.object({
	id: Uuid_With_Default,
	created: Datetime_Now,
	/** Required and initially equal to `created`. */
	updated: Datetime_Now,
});
export type Cell_Json = z.infer<typeof Cell_Json>;
export type Cell_Json_Input = z.input<typeof Cell_Json>;
