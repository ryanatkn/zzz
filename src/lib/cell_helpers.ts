import {z} from 'zod';
import {DEV} from 'esm-env';

/** Sentinel value to indicate a parser has completely handled a property */
export const HANDLED = Symbol('HANDLED_BY_PARSER');

/** Sentinel value to explicitly indicate fallback to default decoding */
export const USE_DEFAULT = Symbol('USE_DEFAULT_DECODING'); // TODO better name?

// Constants for date formatting
export const FILE_SHORT_DATE_FORMAT = 'MMM d, p';
export const FILE_DATE_FORMAT = 'MMM d, yyyy h:mm:ss a';
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
 * @param schema The array Zod schema to annotate (or ZodDefault containing an array)
 * @param class_name The name of the class to instantiate for each element
 * @returns The original schema with metadata attached
 */
export const cell_array = <T extends z.ZodTypeAny>(schema: T, class_name: string): T => {
	// Use type casting to access the inner ZodArray if this is a ZodDefault
	// This safely handles both direct ZodArrays and ZodDefault<ZodArray>
	const array_schema =
		schema instanceof z.ZodDefault
			? (schema._def.innerType as z.ZodArray<any>)
			: (schema as unknown as z.ZodArray<any>);

	// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
	if (!array_schema._def) {
		if (DEV) console.error('cell_array: Schema is not a ZodArray or ZodDefault<ZodArray>');
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
	[K in T_Key]?: (
		value: unknown,
	) => z.infer<T_Schema>[K] | undefined | typeof HANDLED | typeof USE_DEFAULT;
};

/**
 * Get schema class information from a Zod schema.
 * This helps determine how to decode values based on their schema definition.
 */
export const get_schema_class_info = (
	schema: z.ZodTypeAny | null | undefined,
): Schema_Class_Info | null => {
	if (!schema) return null;

	// Handle ZodEffects (refinement, transformation, etc.)
	if (schema instanceof z.ZodEffects) {
		return get_schema_class_info(schema.innerType());
	}

	// Handle ZodObject with _zMetadata property
	if (
		schema instanceof z.ZodObject &&
		typeof schema._def.description === 'string' &&
		schema._def.description.startsWith('_zMetadata:')
	) {
		const class_name = schema._def.description.split(':')[1];
		return {type: 'ZodObject', class_name, is_array: false};
	}

	// Handle ZodArray
	if (schema instanceof z.ZodArray) {
		// Get class name from schema metadata if present
		const element_class =
			(schema._def as any)[ZOD_ELEMENT_CLASS_NAME] ||
			get_schema_class_info(schema.element)?.class_name;
		return {
			type: 'ZodArray',
			is_array: true,
			element_class,
		};
	}

	// Get class name from schema metadata if present
	const class_name = (schema as any)[ZOD_CELL_CLASS_NAME];
	if (class_name) {
		return {type: schema.constructor.name, class_name, is_array: false};
	}

	// Handle ZodDefault by unwrapping and checking the inner type
	if (schema instanceof z.ZodDefault) {
		const inner_info = get_schema_class_info(schema._def.innerType);
		if (inner_info) return inner_info;
	}

	// Handle ZodBranded
	if (schema instanceof z.ZodBranded) {
		return {type: 'ZodBranded', is_array: false};
	}

	// Handle ZodMap and ZodSet
	if (schema instanceof z.ZodMap) {
		return {type: 'ZodMap', is_array: false};
	}
	if (schema instanceof z.ZodSet) {
		return {type: 'ZodSet', is_array: false};
	}

	// Handle other types
	return {type: schema.constructor.name, is_array: false};
};
