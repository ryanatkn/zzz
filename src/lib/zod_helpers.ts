import {z} from 'zod';
import {EMPTY_ARRAY} from '@ryanatkn/belt/array.js';
import {SvelteMap} from 'svelte/reactivity';
import {ensure_end, ensure_start, strip_end, strip_start} from '@ryanatkn/belt/string.js';

export const Any = z.any();
export type Any = z.infer<typeof Any>;

export const Type_Literal = z.string().min(1).brand('Type_Literal');
export type Type_Literal = z.infer<typeof Type_Literal>;

// TODO rethink with ensure/strip usages, normally we'd want to validate these not transform
export const Path_With_Trailing_Slash = z.string().transform((v) => ensure_end(v, '/'));
export type Path_With_Trailing_Slash = z.infer<typeof Path_With_Trailing_Slash>;

export const Path_Without_Trailing_Slash = z.string().transform((v) => strip_end(v, '/'));
export type Path_Without_Trailing_Slash = z.infer<typeof Path_Without_Trailing_Slash>;

export const Path_With_Leading_Slash = z.string().transform((v) => ensure_start(v, '/'));
export type Path_With_Leading_Slash = z.infer<typeof Path_With_Leading_Slash>;

export const Path_Without_Leading_Slash = z.string().transform((v) => strip_start(v, '/'));
export type Path_Without_Leading_Slash = z.infer<typeof Path_Without_Leading_Slash>;

export const Svelte_Map_Schema = z.instanceof(SvelteMap);
export type Svelte_Map_Schema = z.infer<typeof Svelte_Map_Schema>;

/**
 * Returns an ISO datetime string that is guaranteed to be monotonically increasing.
 * If called multiple times within the same millisecond, it increments the value
 * by one millisecond to ensure uniqueness and order preservation.
 */
export const get_datetime_now = (): Datetime => new Date().toISOString() as Datetime; // TODO maybe memoize one by `Date.now()`? or is the overhead not worth it?

// TODO move these? helpers at least - maybe `types.ts`? is belt going to use zod?
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

// TODO type
export const get_innermost_type_name = (schema: z.ZodTypeAny): any =>
	get_innermost_type(schema)._def.typeName;

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

export const stringify_zod_error = (error: z.ZodError): string =>
	error.issues.map((issue) => issue.message).join(', '); // TODO improve
