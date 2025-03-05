import {z} from 'zod';

/**
 * Get keys from a Zod schema object
 */
export type Schema_Keys<T extends z.ZodType> = keyof z.infer<T> & string;

/**
 * Get value type for a specific key in a Zod schema
 */
export type Schema_Value<T extends z.ZodType, K extends Schema_Keys<T>> = z.infer<T>[K];
