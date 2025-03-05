import {z} from 'zod';

// Metadata properties for Zod schemas.
// These constants are used to attach class information to schemas
export const ZOD_CELL_CLASS_NAME = 'zzz_cell_class_name';
export const ZOD_ELEMENT_CLASS_NAME = 'zzz_element_class_name';

/**
 * Attaches class name metadata to a Zod schema for cell instantiation.
 * This allows the cell system to know which class to instantiate for a given schema.
 *
 * @param schema The Zod schema to annotate
 * @param className The name of the class to instantiate for this schema
 * @returns The original schema with metadata attached
 */
export const cell_class = <T extends z.ZodTypeAny>(schema: T, className: string): T => {
	// Instead of using transform which changes the type, just attach metadata
	(schema as any)[ZOD_CELL_CLASS_NAME] = className;
	return schema;
};

/**
 * Attaches element class name metadata to an array schema for cell array instantiation.
 * This allows the cell system to know which class to instantiate for each element in the array.
 *
 * @param schema The array Zod schema to annotate (or ZodDefault containing an array)
 * @param className The name of the class to instantiate for each element
 * @returns The original schema with metadata attached
 */
export const cell_array = <T extends z.ZodTypeAny>(schema: T, className: string): T => {
	// Use type casting to access the inner ZodArray if this is a ZodDefault
	// This safely handles both direct ZodArrays and ZodDefault<ZodArray>
	const arraySchema =
		schema instanceof z.ZodDefault
			? (schema._def.innerType as z.ZodArray<any>)
			: (schema as unknown as z.ZodArray<any>);

	// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
	if (!arraySchema._def) {
		console.warn('cell_array: Schema is not a ZodArray or ZodDefault<ZodArray>');
		return schema;
	}

	// Add the element_class property to the array schema
	(arraySchema._def as any)[ZOD_ELEMENT_CLASS_NAME] = className;
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
 * Get schema class information from a Zod schema.
 * This helps determine how to decode values based on their schema definition.
 */
export const get_schema_class_info = (
	schema: z.ZodTypeAny,
): {
	type?: string;
	is_array?: boolean;
	class_name?: string;
	element_class?: string;
} | null => {
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
		const element_info = get_schema_class_info(schema.element);
		return {
			type: 'ZodArray',
			is_array: true,
			element_class: element_info?.class_name,
		};
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
