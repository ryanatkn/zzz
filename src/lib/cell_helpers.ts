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

/**
 * Utility function to extract cell-specific class information from a schema
 *
 * @param field_schema The zod schema to examine
 * @returns Object containing class information
 */
export const get_schema_class_info = (
	field_schema: z.ZodTypeAny,
): {
	type?: string;
	is_array?: boolean;
	class_name?: string;
	element_class?: string;
} | null => {
	if (!field_schema) return null;

	const def = (field_schema as any)._def;
	if (!def) return null;

	const result: {
		type?: string;
		is_array?: boolean;
		class_name?: string;
		element_class?: string;
	} = {
		type: def.typeName,
	};

	// Check if it's an array
	if (def.typeName === 'ZodArray') {
		result.is_array = true;

		// Look for element class metadata
		if (def[ZOD_ELEMENT_CLASS_NAME]) {
			result.element_class = def[ZOD_ELEMENT_CLASS_NAME];
		}

		// Also look at the inner type
		const element_type = def.type;
		if (element_type?.[ZOD_CELL_CLASS_NAME]) {
			result.element_class = element_type[ZOD_CELL_CLASS_NAME];
		}
	}
	// Check for class metadata on the field itself
	else if ((field_schema as any)[ZOD_CELL_CLASS_NAME]) {
		result.class_name = (field_schema as any)[ZOD_CELL_CLASS_NAME];
	}

	return result;
};
