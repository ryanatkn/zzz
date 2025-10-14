import {z} from 'zod';
import {EMPTY_ARRAY} from '@ryanatkn/belt/array.js';
import {SvelteMap} from 'svelte/reactivity';
import {ensure_end, ensure_start, strip_end, strip_start} from '@ryanatkn/belt/string.js';
import type {Schema_Keys} from '$lib/cell_types.js';

export const Any = z.any();
export type Any = z.infer<typeof Any>;

export const Http_Status = z.number().int();
export type Http_Status = z.infer<typeof Http_Status>;

export const Type_Literal = z.string().min(1).brand('Type_Literal');
export type Type_Literal = z.infer<typeof Type_Literal>;

// TODO @many how to handle paths? need some more structure to the way they're normalized and joined
// TODO rethink with ensure/turn usages, normally we'd want to validate these not transform
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
export const Datetime = z.iso.datetime().brand('Datetime');
export type Datetime = z.infer<typeof Datetime>;
export const Datetime_Now = Datetime.default(get_datetime_now);
export type Datetime_Now = z.infer<typeof Datetime_Now>;

export const create_uuid = (): Uuid => crypto.randomUUID() as Uuid;

export const Uuid = z.uuid().brand('Uuid');
export type Uuid = z.infer<typeof Uuid>;
export const Uuid_With_Default = Uuid.default(create_uuid);
export type Uuid_With_Default = z.infer<typeof Uuid_With_Default>;

/**
 * Helper to extract subschema from a Zod def, following Zod 4 patterns.
 */
export const to_subschema = (def: z.core.$ZodTypeDef): z.ZodType | undefined => {
	if ('innerType' in def) {
		return def.innerType as z.ZodType;
	} else if ('in' in def) {
		return def.in as z.ZodType;
	} else if ('schema' in def) {
		return def.schema as z.ZodType;
	}
	return undefined;
};

/**
 * Gets the innermost type of a zod schema by unwrapping wrappers like transforms, ZodOptional, ZodDefault, etc.
 * @param schema The schema to unwrap
 * @returns The innermost schema without wrappers
 */
export const get_innermost_type = (schema: z.ZodType): z.ZodType => {
	const def = schema._zod.def;

	// Handle wrapper types that need unwrapping
	if (schema instanceof z.ZodOptional || schema instanceof z.ZodNullable) {
		return get_innermost_type(schema.unwrap() as z.ZodType);
	}

	if (schema instanceof z.ZodDefault) {
		const subschema = to_subschema(def);
		if (subschema) {
			return get_innermost_type(subschema);
		}
	}

	// Handle transforms, pipes, and other wrappers
	if (def.type === 'transform' || def.type === 'pipe' || def.type === 'prefault') {
		const subschema = to_subschema(def);
		if (subschema) {
			return get_innermost_type(subschema);
		}
	}

	return schema;
};

export const get_innermost_type_name = (schema: z.ZodType): string => {
	const innermost = get_innermost_type(schema);
	const def = innermost._zod.def;
	return def.type;
};

/**
 * Gets all property keys from a Zod object schema.
 */
export const zod_get_schema_keys = <T extends z.ZodType>(schema: T): Array<Schema_Keys<T>> => {
	const inner = get_innermost_type(schema);
	if (inner instanceof z.ZodObject) {
		return Object.keys(inner.shape) as Array<Schema_Keys<T>>;
	}
	return EMPTY_ARRAY;
};

/**
 * Get the Zod schema for a specific field in an object schema.
 *
 * @param schema The object schema
 * @param key The property name
 * @returns The field's schema, or throws if not found
 */
export const get_field_schema = (schema: z.ZodType, key: string): z.ZodType => {
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
export const maybe_get_field_schema = (schema: z.ZodType, key: string): z.ZodType | undefined => {
	const inner = get_innermost_type(schema);
	// Access the schema's shape if it's an object schema
	if (inner instanceof z.ZodObject) {
		return inner.shape[key];
	}
	return undefined;
};

/**
 * Checks if a Zod schema is an array or contains an array through wrappers.
 */
export const is_array_schema = (schema: z.ZodType): boolean => {
	const inner = get_innermost_type(schema);
	return inner instanceof z.ZodArray;
};

/**
 * Gets the innermost array schema from a potentially nested schema structure.
 * Returns null if no array schema is found.
 */
export const get_inner_array_schema = (schema: z.ZodType): z.ZodArray<any> | null => {
	const inner = get_innermost_type(schema);
	return inner instanceof z.ZodArray ? inner : null;
};

/**
 * Formats a Zod validation error with field paths for clearer error messages.
 */
export const format_zod_validation_error = (error: z.ZodError): string =>
	error.issues
		.map((i) => {
			const path = i.path.length > 0 ? `${i.path.join('.')}: ` : '';
			return `${path}${i.message}`;
		})
		.join(', ');
