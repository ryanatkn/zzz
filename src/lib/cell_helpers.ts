import {z} from 'zod';

import type {Cell_Json} from '$lib/cell_types.js';

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
	type?: string;
	is_array?: boolean;
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
		console.warn('cell_array: Schema is not a ZodArray or ZodDefault<ZodArray>');
		return schema;
	}

	// Add the element_class property to the array schema
	(array_schema._def as any)[ZOD_ELEMENT_CLASS_NAME] = class_name;
	return schema;
};

// A type helper that makes it easier to define value parsers with correct input types
export type Value_Parser<
	TSchema extends z.ZodType,
	TKey extends keyof z.infer<TSchema> & string = keyof z.infer<TSchema> & string,
> = {
	[K in TKey]?: (value: unknown) => z.infer<TSchema>[K] | undefined;
};

/**
 * Type helper for parsers that includes base schema properties.
 * Use this instead of Value_Parser when creating parsers for cells
 * to properly type the base properties.
 */
export type Cell_Value_Parser<
	TSchema extends z.ZodType,
	TKey extends keyof z.infer<TSchema> & string = keyof z.infer<TSchema> & string,
> = Value_Parser<TSchema, TKey> & Value_Parser<z.ZodType<Cell_Json>, keyof Cell_Json & string>;

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
		return {type: 'ZodObject', class_name};
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
		return {type: schema.constructor.name, class_name};
	}

	// Handle ZodBranded
	if (schema instanceof z.ZodBranded) {
		return {type: 'ZodBranded'};
	}

	// Handle ZodMap and ZodSet
	if (schema instanceof z.ZodMap) {
		return {type: 'ZodMap'};
	}
	if (schema instanceof z.ZodSet) {
		return {type: 'ZodSet'};
	}

	// Handle other types
	return {type: schema.constructor.name};
};
