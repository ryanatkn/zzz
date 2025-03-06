import {z} from 'zod';
import {EMPTY_ARRAY} from '@ryanatkn/belt/array.js';

// TODO move these?
export const Datetime = z.string().datetime().brand('Datetime');
export type Datetime = z.infer<typeof Datetime>;
export const Datetime_Now = Datetime.default(() => new Date().toISOString());
export type Datetime_Now = z.infer<typeof Datetime_Now>;

export const Uuid_Base = z.string().uuid().brand('Uuid');
export type Uuid_Base = z.infer<typeof Uuid_Base>;
export const Uuid = Uuid_Base.default(() => globalThis.crypto.randomUUID());
export type Uuid = z.infer<typeof Uuid>;

/**
 * Gets all property keys from a Zod object schema.
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
 * Get the Zod schema for a specific field in an object schema.
 *
 * @param schema The object schema
 * @param key The property name
 * @returns The field's schema, or throws if not found
 */
export const get_field_schema = (schema: z.ZodTypeAny, key: string): z.ZodTypeAny => {
	const field = maybe_get_field_schema(schema, key);
	if (!field) {
		throw new Error(`Field "${key}" not found in schema`);
	}
	return field;
};

/**
 * Get the Zod schema for a specific field in an object schema, returning undefined if not found.
 *
 * @param schema The object schema
 * @param key The property name
 * @returns The field's schema, or undefined if not found
 */
export const maybe_get_field_schema = (
	schema: z.ZodTypeAny,
	key: string,
): z.ZodTypeAny | undefined => {
	try {
		// Access the schema's shape if it's an object schema
		if (schema instanceof z.ZodObject) {
			return schema.shape[key];
		} else if (schema instanceof z.ZodEffects) {
			// For ZodEffects (like transforms), get field from the inner schema
			return maybe_get_field_schema(schema.innerType(), key);
		} else if (schema instanceof z.ZodDefault) {
			// For ZodDefault, get field from the inner schema
			return maybe_get_field_schema(schema._def.innerType, key);
		} else {
			return undefined;
		}
	} catch {
		return undefined;
	}
};
