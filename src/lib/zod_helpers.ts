import {z} from 'zod';
import {EMPTY_ARRAY} from '@ryanatkn/belt/array.js';

/**
 * Gets all property keys from a Zod object schema
 */
export const zod_get_schema_keys = <T extends z.ZodTypeAny>(schema: T): Array<string> => {
	if (schema instanceof z.ZodObject) {
		// For ZodObject, we can access the shape to get the keys
		return Object.keys(schema._def.shape());
	} else if (schema instanceof z.ZodEffects) {
		// For ZodEffects (like transforms), get keys from the inner schema
		return zod_get_schema_keys(schema.innerType());
	} else if (schema instanceof z.ZodDefault) {
		// For ZodDefault, get keys from the inner schema
		return zod_get_schema_keys(schema._def.innerType);
	} else {
		// Fallback for other schema types
		return EMPTY_ARRAY;
	}
};
