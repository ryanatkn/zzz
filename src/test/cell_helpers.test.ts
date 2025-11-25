// @slop Claude Sonnet 3.7

import {describe, test, expect} from 'vitest';
import {z} from 'zod';

import {get_schema_class_info} from '$lib/cell_helpers.js';

describe('get_schema_class_info', () => {
	test('handles null or undefined schemas', () => {
		expect(get_schema_class_info(null)).toBeNull();
		expect(get_schema_class_info(undefined)).toBeNull();
	});

	test('identifies basic schema types correctly', () => {
		const string_schema = z.string();
		const number_schema = z.number();
		const boolean_schema = z.boolean();

		const string_info = get_schema_class_info(string_schema);
		const number_info = get_schema_class_info(number_schema);
		const boolean_info = get_schema_class_info(boolean_schema);

		expect(string_info?.type).toBe('ZodString');
		expect(string_info?.is_array).toBe(false);

		expect(number_info?.type).toBe('ZodNumber');
		expect(number_info?.is_array).toBe(false);

		expect(boolean_info?.type).toBe('ZodBoolean');
		expect(boolean_info?.is_array).toBe(false);
	});

	test('identifies array schemas correctly', () => {
		const string_array = z.array(z.string());
		const number_array = z.array(z.number());
		const object_array = z.array(z.object({name: z.string()}));

		const string_array_info = get_schema_class_info(string_array);
		const number_array_info = get_schema_class_info(number_array);
		const object_array_info = get_schema_class_info(object_array);

		// Test array identification
		expect(string_array_info?.type).toBe('ZodArray');
		expect(string_array_info?.is_array).toBe(true);

		expect(number_array_info?.type).toBe('ZodArray');
		expect(number_array_info?.is_array).toBe(true);

		expect(object_array_info?.type).toBe('ZodArray');
		expect(object_array_info?.is_array).toBe(true);
	});

	test('handles default wrapped schemas', () => {
		const string_with_default = z.string().default('default');
		const array_with_default = z.array(z.string()).default([]);

		const string_default_info = get_schema_class_info(string_with_default);
		const array_default_info = get_schema_class_info(array_with_default);

		// Default shouldn't change the core type
		expect(string_default_info?.type).toBe('ZodString');
		expect(string_default_info?.is_array).toBe(false);

		// This is what's failing in the test - default-wrapped arrays should still be identified as arrays
		expect(array_default_info?.type).toBe('ZodArray');
		expect(array_default_info?.is_array).toBe(true);
	});

	test('handles object schemas', () => {
		const object_schema = z.object({
			name: z.string(),
			count: z.number(),
		});

		const object_info = get_schema_class_info(object_schema);
		expect(object_info?.type).toBe('ZodObject');
		expect(object_info?.is_array).toBe(false);
	});

	test('detects class names set with cell_class', () => {
		const schema = z.object({id: z.string()});
		const schema_with_class = schema.meta({cell_class_name: 'TestClass'});

		const info = get_schema_class_info(schema_with_class);
		expect(info?.class_name).toBe('TestClass');
	});

	test('detects element classes from element metadata', () => {
		const element_schema = z.string().meta({cell_class_name: 'ElementClass'});
		const array_schema = z.array(element_schema);

		const info = get_schema_class_info(array_schema);
		expect(info?.is_array).toBe(true);
		expect(info?.element_class).toBe('ElementClass');
	});

	test('handles default-wrapped array with element metadata', () => {
		const element_schema = z.string().meta({cell_class_name: 'ElementClass'});
		const array_schema = z.array(element_schema).default([]);

		const info = get_schema_class_info(array_schema);
		expect(info?.is_array).toBe(true);
		expect(info?.element_class).toBe('ElementClass');
	});

	test('reads element class from nested element schema', () => {
		// Test that metadata on element schema is properly read
		const element_schema = z
			.object({name: z.string()})
			.meta({cell_class_name: 'DirectElementClass'});
		const array_schema = z.array(element_schema);

		// Verify that get_schema_class_info can read element metadata
		const info = get_schema_class_info(array_schema);
		expect(info?.is_array).toBe(true);
		expect(info?.element_class).toBe('DirectElementClass');
	});

	test('handles ZodDefault containing a ZodArray', () => {
		// Create array schema and wrap in ZodDefault
		const array_schema = z.array(z.string());
		const array_schema_default = array_schema.default([]);

		// We can see what the internal structure of ZodDefault looks like
		expect(array_schema_default._zod.def).toBeDefined();
		expect(array_schema_default._zod.def.type).toBe('default');
		expect(array_schema_default._zod.def.innerType).toBeDefined();
		expect(array_schema_default._zod.def.innerType.def.type).toBe('array');

		// Now test the function with our default-wrapped array
		const info = get_schema_class_info(array_schema_default);

		// The function should see through the ZodDefault to the ZodArray inside
		expect(info?.type).toBe('ZodArray');
		expect(info?.is_array).toBe(true);
	});

	test('handles complex nested schema wrapping', () => {
		// Create nested wrapping: ZodDefault -> ZodOptional -> ZodArray
		const nested_array_schema = z.array(z.string()).optional().default([]);

		const nested_info = get_schema_class_info(nested_array_schema);
		expect(nested_info?.type).toBe('ZodArray');
		expect(nested_info?.is_array).toBe(true);

		// More extreme nesting: ZodDefault -> ZodOptional -> ZodDefault -> ZodArray
		const extreme_nesting = z.array(z.number()).default([]).optional().default([]);

		const extreme_info = get_schema_class_info(extreme_nesting);
		expect(extreme_info?.type).toBe('ZodArray');
		expect(extreme_info?.is_array).toBe(true);
	});

	test('handles ZodEffects wrapping arrays', () => {
		// ZodEffects (refinement) wrapping an array
		const refined_array = z
			.array(z.string())
			.refine((arr) => arr.length > 0, {message: 'Array must not be empty'});

		const refined_info = get_schema_class_info(refined_array);
		expect(refined_info?.type).toBe('ZodArray');
		expect(refined_info?.is_array).toBe(true);

		// ZodEffects (transform) wrapping an array with default
		const transformed_array = z
			.array(z.number())
			.default([])
			.transform((arr) => arr.map((n) => n * 2));

		const transformed_info = get_schema_class_info(transformed_array);
		expect(transformed_info?.type).toBe('ZodArray');
		expect(transformed_info?.is_array).toBe(true);
	});

	test('handles combinations of optional, default, and refinement', () => {
		// Complex chain: optional -> default -> refine -> transform -> array
		const complex_chain = z
			.array(z.string())
			.refine((arr) => arr.every((s) => s.length > 0), {message: 'No empty strings'})
			.transform((arr) => arr.map((s) => s.trim()))
			.default([])
			.optional();

		const chain_info = get_schema_class_info(complex_chain);
		expect(chain_info?.type).toBe('ZodArray');
		expect(chain_info?.is_array).toBe(true);
	});

	test('recursive unwrapping preserves metadata through wrappers', () => {
		// Create an array with element that has metadata
		const element = z.string().meta({cell_class_name: 'TestElement'});
		const array_with_class = z.array(element);

		// Wrap it multiple times
		const wrapped_array = array_with_class.optional().default([]);

		// Check that metadata is preserved
		const info = get_schema_class_info(wrapped_array);
		expect(info?.element_class).toBe('TestElement');
		expect(info?.is_array).toBe(true);
	});

	test('handles deeply nested schemas with element metadata', () => {
		// Create a deeply nested schema with element metadata
		const element = z.string().meta({cell_class_name: 'NestedElement'});
		const nested_schema = z.array(element).optional().default([]);

		// Verify metadata is found correctly through the wrappers
		const info = get_schema_class_info(nested_schema);
		expect(info?.is_array).toBe(true);
		expect(info?.element_class).toBe('NestedElement');
	});
});

describe('cell_class', () => {
	test('adds class name metadata to schemas', () => {
		const schema = z.object({name: z.string()});
		const result = schema.meta({cell_class_name: 'TestCellClass'});

		// Should add the metadata via .meta()
		expect(result.meta()?.cell_class_name).toBe('TestCellClass');

		// Should return a new schema instance (due to .meta() creating a new instance)
		expect(result).not.toBe(schema);

		// Get schema info should report it correctly
		const info = get_schema_class_info(result);
		expect(info?.class_name).toBe('TestCellClass');
	});
});
