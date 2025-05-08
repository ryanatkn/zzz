import {z} from 'zod';
import {DEV} from 'esm-env';
import {get_inner_array_schema, get_innermost_type} from '$lib/zod_helpers.js';

/** Sentinel value to indicate a parser has completely handled a property */
export const HANDLED = Symbol('HANDLED_BY_PARSER');

// Constants for date formatting
export const FILE_SHORT_DATE_FORMAT = 'MMM d, p';
export const FILE_DATETIME_FORMAT = 'MMM d, yyyy h:mm:ss a';
export const FILE_TIME_FORMAT = 'HH:mm:ss';

// Metadata properties for Zod schemas.
// These constants are used to attach class information to schemas.
// It's a bit hacky but feels better than abusing `.description` with JSON.
// Zod does not support metadata - https://github.com/colinhacks/zod/issues/273
// Maybe we should follow this recommended pattern instead of adding properties:
// type MyEndpoint<T extends z.Schema<any>> = {
//   validator: T;
//   label: string;
// }
export const ZOD_CELL_CLASS_NAME = 'zzz_cell_class_name';
export const ZOD_ELEMENT_CLASS_NAME = 'zzz_element_class_name';

/**
 * Schema class information extracted from a Zod schema.
 */
export interface Schema_Class_Info {
	type: string;
	is_array: boolean;
	class_name?: string;
	element_class?: string;
}

/**
 * Attaches class name metadata to a Zod schema for cell instantiation.
 * This allows the cell system to know which class to instantiate for a given schema.
 *
 * Works with both regular schemas and extended cell schemas.
 *
 * @param schema The Zod schema to annotate
 * @param class_name The name of the class to instantiate for this schema
 * @returns The original schema with metadata attached
 */
export const cell_class = <T extends z.ZodTypeAny>(schema: T, class_name: string): T => {
	// Instead of using transform which changes the type, just attach metadata
	(schema as any)[ZOD_CELL_CLASS_NAME] = class_name;
	return schema;
};

/**
 * Attaches element class name metadata to an array schema for cell array instantiation.
 * This allows the cell system to know which class to instantiate for each element in the array.
 *
 * @param schema The array Zod schema to annotate (or schema containing an array)
 * @param class_name The name of the class to instantiate for each element
 * @returns The original schema with metadata attached
 */
export const cell_array = <T extends z.ZodTypeAny>(schema: T, class_name: string): T => {
	const array_schema = get_inner_array_schema(schema);

	if (!array_schema) {
		if (DEV) console.error('cell_array: Schema is not or does not contain a ZodArray');
		return schema;
	}

	// Add the element_class property to the array schema
	(array_schema._def as any)[ZOD_ELEMENT_CLASS_NAME] = class_name;
	return schema;
};

// A type helper that makes it easier to define value parsers with correct input types
export type Value_Parser<
	T_Schema extends z.ZodType,
	T_Key extends keyof z.infer<T_Schema> = keyof z.infer<T_Schema>,
> = {
	[K in T_Key]?: (value: unknown) => z.infer<T_Schema>[K] | undefined;
};

/**
 * Type helper for decoders that includes base schema properties.
 * Use this instead of Value_Parser when creating decoders for cells
 * to properly type the base properties.
 */
export type Cell_Value_Decoder<
	T_Schema extends z.ZodType,
	T_Key extends keyof z.infer<T_Schema> = keyof z.infer<T_Schema>,
> = {
	[K in T_Key]?: (value: unknown) => z.infer<T_Schema>[K] | undefined | typeof HANDLED;
};

/**
 * Get schema class information from a Zod schema.
 * This helps determine how to decode values based on their schema definition.
 */
export const get_schema_class_info = (
	schema: z.ZodTypeAny | null | undefined,
): Schema_Class_Info | null => {
	if (!schema) return null;

	// Unwrap to get the core schema
	const unwrapped = get_innermost_type(schema);

	// Handle ZodArray
	if (unwrapped instanceof z.ZodArray) {
		// Get class name from schema metadata if present
		const element_class =
			(unwrapped._def as any)[ZOD_ELEMENT_CLASS_NAME] ||
			get_schema_class_info(unwrapped.element)?.class_name;
		return {
			type: 'ZodArray',
			is_array: true,
			element_class,
		};
	}

	// Get class name from schema metadata if present for any schema type
	const class_name = (schema as any)[ZOD_CELL_CLASS_NAME];
	if (class_name) {
		return {type: unwrapped.constructor.name, class_name, is_array: false};
	}

	// Handle ZodObject with _zMetadata property
	if (
		unwrapped instanceof z.ZodObject &&
		typeof unwrapped._def.description === 'string' &&
		unwrapped._def.description.startsWith('_zMetadata:')
	) {
		const class_name = unwrapped._def.description.split(':')[1];
		return {type: 'ZodObject', class_name, is_array: false};
	}

	// Handle other specific types
	if (unwrapped instanceof z.ZodBranded) {
		return {type: 'ZodBranded', is_array: false};
	}
	if (unwrapped instanceof z.ZodMap) {
		return {type: 'ZodMap', is_array: false};
	}
	if (unwrapped instanceof z.ZodSet) {
		return {type: 'ZodSet', is_array: false};
	}

	// Default case for any other schema type
	return {type: unwrapped.constructor.name, is_array: false};
};
