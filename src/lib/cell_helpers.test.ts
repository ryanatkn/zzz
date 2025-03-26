import {describe, test, expect} from 'vitest';
import {z} from 'zod';

import {
	get_schema_class_info,
	cell_class,
	cell_array,
	ZOD_CELL_CLASS_NAME,
	ZOD_ELEMENT_CLASS_NAME,
} from '$lib/cell_helpers.js';

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
		const schema_with_class = cell_class(schema, 'Test_Class');

		const info = get_schema_class_info(schema_with_class);
		expect(info?.class_name).toBe('Test_Class');
	});

	test('detects element classes set with cell_array', () => {
		const array_schema = z.array(z.string());
		const array_with_class = cell_array(array_schema, 'Element_Class');

		const info = get_schema_class_info(array_with_class);
		expect(info?.is_array).toBe(true);
		expect(info?.element_class).toBe('Element_Class');
	});

	test('handles default-wrapped array with element class', () => {
		const array_schema = z.array(z.string()).default([]);
		const array_with_class = cell_array(array_schema, 'Element_Class');

		const info = get_schema_class_info(array_with_class);
		expect(info?.is_array).toBe(true);
		expect(info?.element_class).toBe('Element_Class');
	});

	test('directly inspects array schema internal structure', () => {
		// This test looks at the internal structure of ZodArray to verify our assumptions
		const array_schema = z.array(z.string());

		// Check that the schema has the expected internal structure
		expect(array_schema._def).toBeDefined();
		expect(array_schema._def.typeName).toBe('ZodArray');

		// Now add the element class metadata
		(array_schema._def as any)[ZOD_ELEMENT_CLASS_NAME] = 'Direct_Element_Class';

		// Verify that get_schema_class_info can read this metadata
		const info = get_schema_class_info(array_schema);
		expect(info?.is_array).toBe(true);
		expect(info?.element_class).toBe('Direct_Element_Class');
	});

	test('handles ZodDefault containing a ZodArray', () => {
		// Create array schema and wrap in ZodDefault
		const array_schema = z.array(z.string());
		const array_schema_default = array_schema.default([]);

		// We can see what the internal structure of ZodDefault looks like
		expect(array_schema_default._def).toBeDefined();
		expect(array_schema_default._def.typeName).toBe('ZodDefault');
		expect(array_schema_default._def.innerType).toBeDefined();
		expect(array_schema_default._def.innerType._def.typeName).toBe('ZodArray');

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
		// Create an array with element class metadata
		const array_with_class = z.array(z.string());
		(array_with_class._def as any)[ZOD_ELEMENT_CLASS_NAME] = 'Test_Element';

		// Wrap it multiple times
		const wrapped_array = array_with_class.optional().default([]);

		// Check that metadata is preserved
		const info = get_schema_class_info(wrapped_array);
		expect(info?.element_class).toBe('Test_Element');
		expect(info?.is_array).toBe(true);
	});

	test('handles cell_array with deeply nested schemas', () => {
		// Create a deeply nested schema and apply cell_array
		const nested_schema = z.array(z.string()).optional().default([]);
		const result = cell_array(nested_schema, 'Nested_Element');

		// Verify metadata was attached correctly through the wrappers
		const info = get_schema_class_info(result);
		expect(info?.is_array).toBe(true);
		expect(info?.element_class).toBe('Nested_Element');
	});
});

describe('cell_array', () => {
	test('adds element class metadata to direct array schemas', () => {
		const array_schema = z.array(z.string());
		cell_array(array_schema, 'Test_Element');

		// Verify metadata was added
		expect((array_schema._def as any)[ZOD_ELEMENT_CLASS_NAME]).toBe('Test_Element');

		// Get schema info should report it correctly
		const info = get_schema_class_info(array_schema);
		expect(info?.element_class).toBe('Test_Element');
	});

	test('adds element class metadata to default-wrapped array schemas', () => {
		const array_schema = z.array(z.string()).default([]);
		cell_array(array_schema, 'Default_Test_Element');

		// Verify metadata was added to inner ZodArray, not ZodDefault
		const inner_array = array_schema._def.innerType;
		expect((inner_array._def as any)[ZOD_ELEMENT_CLASS_NAME]).toBe('Default_Test_Element');

		// Get schema info should report it correctly
		const info = get_schema_class_info(array_schema);
		expect(info?.element_class).toBe('Default_Test_Element');
	});

	test('handles errors gracefully with non-array schemas', () => {
		const string_schema = z.string();
		// This should not throw but should log an error
		const result = cell_array(string_schema, 'Should_Not_Apply');

		// Should return the original schema unmodified
		expect(result).toBe(string_schema);

		// Should not have added the metadata
		expect((string_schema as any)[ZOD_ELEMENT_CLASS_NAME]).toBeUndefined();
	});
});

describe('cell_class', () => {
	test('adds class name metadata to schemas', () => {
		const schema = z.object({name: z.string()});
		const result = cell_class(schema, 'Test_Cell_Class');

		// Should add the metadata
		expect((result as any)[ZOD_CELL_CLASS_NAME]).toBe('Test_Cell_Class');

		// Should return the same schema instance
		expect(result).toBe(schema);

		// Get schema info should report it correctly
		const info = get_schema_class_info(result);
		expect(info?.class_name).toBe('Test_Cell_Class');
	});
});
