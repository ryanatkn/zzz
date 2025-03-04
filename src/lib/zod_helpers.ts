import {z} from 'zod';
import {EMPTY_ARRAY} from '@ryanatkn/belt/array.js';

// TODO move these?
export const Datetime = z.string().datetime().brand('Datetime');
export type Datetime = z.infer<typeof Datetime>;
export const Datetime_Now = Datetime.default(() => new Date().toISOString());
export type Datetime_Now = z.infer<typeof Datetime_Now>;

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

/**
 * Get the Zod schema for a specific field in an object schema
 *
 * @param schema The object schema
 * @param key The property name
 * @returns The field's schema, or undefined if not found
 */
export const get_field_schema = (schema: z.ZodTypeAny, key: string): z.ZodTypeAny | undefined => {
	// Access the schema's shape if it's an object schema
	const schema_obj = schema as unknown as {shape?: Record<string, z.ZodTypeAny>};
	return schema_obj.shape?.[key];
};
