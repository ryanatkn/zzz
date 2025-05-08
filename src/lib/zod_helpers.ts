import {z} from 'zod';
import {EMPTY_ARRAY} from '@ryanatkn/belt/array.js';
import {SvelteMap} from 'svelte/reactivity';

export const Any = z.any();

export const Svelte_Map_Schema = z.custom<SvelteMap<any, any>>((val) => val instanceof SvelteMap);

/**
 * Returns an ISO datetime string that is guaranteed to be monotonically increasing.
 * If called multiple times within the same millisecond, it increments the value
 * by one millisecond to ensure uniqueness and order preservation.
 */
export const get_datetime_now = (): Datetime => new Date().toISOString() as Datetime; // TODO maybe memoize one by `Date.now()`? or is the overhead not worth it?

// TODO move these? helpers at least
export const Datetime = z.string().datetime().brand('Datetime');
export type Datetime = z.infer<typeof Datetime>;
export const Datetime_Now = Datetime.default(get_datetime_now);
export type Datetime_Now = z.infer<typeof Datetime_Now>;

export const create_uuid = (): Uuid => crypto.randomUUID() as Uuid;

export const Uuid = z.string().uuid().brand('Uuid');
export type Uuid = z.infer<typeof Uuid>;
export const Uuid_With_Default = Uuid.default(create_uuid);
export type Uuid_With_Default = z.infer<typeof Uuid_With_Default>;

/**
 * Gets the innermost type of a zod schema by unwrapping wrappers like ZodEffects, ZodOptional, ZodDefault, etc.
 * @param schema The schema to unwrap
 * @returns The innermost schema without wrappers
 */
export const get_innermost_type = (schema: z.ZodTypeAny): z.ZodTypeAny => {
	if (schema instanceof z.ZodEffects) {
		return get_innermost_type(schema.innerType());
	}
	if (
		schema instanceof z.ZodOptional ||
		schema instanceof z.ZodNullable ||
		schema instanceof z.ZodBranded
	) {
		return get_innermost_type(schema.unwrap());
	}
	if (schema instanceof z.ZodDefault) {
		return get_innermost_type(schema._def.innerType);
	}
	return schema;
};

/**
 * Gets all property keys from a Zod object schema.
 */
export const zod_get_schema_keys = <T extends z.ZodTypeAny>(schema: T): Array<string> => {
	if (schema instanceof z.ZodObject) {
		// For ZodObject, we can access the shape to get the keys
		return Object.keys(schema._def.shape());
	} else {
		const innerType = get_innermost_type(schema);
		return innerType instanceof z.ZodObject ? Object.keys(innerType._def.shape()) : EMPTY_ARRAY;
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
		throw Error(`Field "${key}" not found in schema`);
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
		const innerType = get_innermost_type(schema);

		// Access the schema's shape if it's an object schema
		if (innerType instanceof z.ZodObject) {
			return innerType.shape[key];
		}

		return undefined;
	} catch {
		return undefined;
	}
};

/**
 * Checks if a Zod schema is an array or contains an array through wrappers.
 */
export const is_array_schema = (schema: z.ZodTypeAny): boolean => {
	const innerType = get_innermost_type(schema);
	return innerType instanceof z.ZodArray;
};

/**
 * Gets the innermost array schema from a potentially nested schema structure.
 * Returns null if no array schema is found.
 */
export const get_inner_array_schema = (schema: z.ZodTypeAny): z.ZodArray<any> | null => {
	const innerType = get_innermost_type(schema);
	return innerType instanceof z.ZodArray ? innerType : null;
};
