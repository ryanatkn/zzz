import {z} from 'zod';
import {get_innermost_type} from '$lib/zod_helpers.js';

/** Sentinel value to indicate a parser has completely handled a property */
export const HANDLED = Symbol('HANDLED_BY_PARSER');

// Constants for date formatting
export const FILE_SHORT_DATE_FORMAT = 'MMM d, p';
export const FILE_DATETIME_FORMAT = 'MMM d, yyyy h:mm:ss a';
export const FILE_TIME_FORMAT = 'HH:mm:ss';

/**
 * Schema class information extracted from a Zod schema.
 */
export interface Schema_Class_Info {
	type: string;
	is_array: boolean;
	class_name?: string;
	element_class?: string;
}

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
	schema: z.ZodType | null | undefined,
): Schema_Class_Info | null => {
	if (!schema) return null;

	// Unwrap to get the core schema
	const unwrapped = get_innermost_type(schema);

	// Handle ZodArray
	if (unwrapped instanceof z.ZodArray) {
		// Get class name from element schema's metadata
		// TODO temporary bug: https://github.com/typescript-eslint/typescript-eslint/issues/11666
		// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
		const element_meta = (unwrapped.element as z.ZodType).meta?.();
		const element_class = element_meta?.cell_class_name as string | undefined;
		return {
			type: 'ZodArray',
			is_array: true,
			element_class,
		};
	}

	// Get class name from schema metadata if present for any schema type
	// TODO temporary bug: https://github.com/typescript-eslint/typescript-eslint/issues/11666
	// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
	const meta = schema.meta?.();
	if (meta?.cell_class_name) {
		return {
			type: unwrapped.constructor.name,
			class_name: meta.cell_class_name as string,
			is_array: false,
		};
	}

	// Handle ZodObject with _zMetadata property
	if (unwrapped instanceof z.ZodObject) {
		const meta = unwrapped.meta();
		if (typeof meta?.description === 'string' && meta.description.startsWith('_zMetadata:')) {
			const class_name = meta.description.split(':')[1];
			return {type: 'ZodObject', class_name, is_array: false};
		}
	}

	// Handle other specific types
	if (unwrapped instanceof z.ZodMap) {
		return {type: 'ZodMap', is_array: false};
	}
	if (unwrapped instanceof z.ZodSet) {
		return {type: 'ZodSet', is_array: false};
	}

	// Default case for any other schema type
	return {type: unwrapped.constructor.name, is_array: false};
};
