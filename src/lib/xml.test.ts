import {test, expect} from 'vitest';
import {z} from 'zod';

import {
	Xml_Attribute,
	Xml_Attribute_Base,
	Xml_Attribute_Key,
	Xml_Attribute_Key_Base,
	Xml_Attribute_Value,
	Xml_Attribute_Value_Base,
} from '$lib/xml.js';

// Basic functionality tests for Xml_Attribute_Key
test('Xml_Attribute_Key - is a Zod string schema', () => {
	expect(Xml_Attribute_Key).toBeInstanceOf(z.ZodType);
});

test('Xml_Attribute_Key - accepts valid strings', () => {
	const valid_keys = ['name', 'id', 'class', 'data-test'];
	for (const key of valid_keys) {
		const result = Xml_Attribute_Key.safeParse(key);
		expect(result.success).toBe(true);
		if (result.success) {
			expect(result.data).toBe(key);
		}
	}
});

test('Xml_Attribute_Key_Base - rejects empty strings', () => {
	const result = Xml_Attribute_Key_Base.safeParse('');
	expect(result.success).toBe(false);
	if (!result.success) {
		expect(result.error.issues[0].code).toBe('too_small');
	}
});

test('Xml_Attribute_Key - allows empty strings due to default', () => {
	// Now testing that it accepts the empty input with our new schema
	const result = Xml_Attribute_Key.safeParse('');
	expect(result.success).toBe(true); // Empty string should now be valid
	if (result.success) {
		expect(result.data).toBe('');
	}
});

test('Xml_Attribute_Key - provides empty string as default when undefined', () => {
	const result = Xml_Attribute_Key.parse(undefined);
	expect(result).toBe(''); // Should be empty string not UUID-based
});

test('Xml_Attribute_Key_Base - rejects undefined', () => {
	const result = Xml_Attribute_Key_Base.safeParse(undefined);
	expect(result.success).toBe(false);
});

// Update this test to reflect that our schema no longer trims whitespace
test('Xml_Attribute_Key - does not trim whitespace with the basic schema', () => {
	// Test with whitespace
	const result = Xml_Attribute_Key.safeParse('  valid-key  ');
	expect(result.success).toBe(true);
	if (result.success) {
		expect(result.data).toBe('  valid-key  '); // Whitespace should not be trimmed
	}

	// Test that a key with only whitespace is acceptable
	const whitespace_result = Xml_Attribute_Key.safeParse('   ');
	expect(whitespace_result.success).toBe(true);
	if (whitespace_result.success) {
		expect(whitespace_result.data).toBe('   ');
	}
});

// Update this test to check that null keys are rejected
test('Xml_Attribute_Key - does not allow null values', () => {
	const result = Xml_Attribute_Key.safeParse(null);
	expect(result.success).toBe(false);
});

// Basic functionality tests for Xml_Attribute_Value
test('Xml_Attribute_Value - is a Zod string schema', () => {
	expect(Xml_Attribute_Value).toBeInstanceOf(z.ZodType);
});

test('Xml_Attribute_Value - accepts any string', () => {
	const valid_values = ['Some text', '', '123', 'true'];
	for (const value of valid_values) {
		const result = Xml_Attribute_Value.safeParse(value);
		expect(result.success).toBe(true);
		if (result.success) {
			expect(result.data).toBe(value);
		}
	}
});

test('Xml_Attribute_Value - provides default empty string when undefined', () => {
	const result = Xml_Attribute_Value.parse(undefined);
	expect(result).toBe('');
});

test('Xml_Attribute_Value_Base - rejects undefined', () => {
	const result = Xml_Attribute_Value_Base.safeParse(undefined);
	expect(result.success).toBe(false);
});

// Basic functionality tests for Xml_Attribute
test('Xml_Attribute - is a Zod object schema', () => {
	expect(Xml_Attribute).toBeInstanceOf(z.ZodType);
});

test('Xml_Attribute - accepts valid attribute objects', () => {
	const valid_uuid = '123e4567-e89b-12d3-a456-426614174000';
	const valid_attribute = {
		id: valid_uuid,
		key: 'class',
		value: 'btn btn-primary',
	};

	const result = Xml_Attribute.safeParse(valid_attribute);
	expect(result.success).toBe(true);
	if (result.success) {
		expect(result.data.id).toBe(valid_uuid);
		expect(result.data.key).toBe('class');
		expect(result.data.value).toBe('btn btn-primary');
	}
});

test('Xml_Attribute - applies defaults for key and value when missing', () => {
	const valid_uuid = '123e4567-e89b-12d3-a456-426614174000';
	const partial_attribute = {
		id: valid_uuid,
	};

	// Need to cast to any to allow missing properties
	const result = Xml_Attribute.safeParse(partial_attribute as any);
	expect(result.success).toBe(true);
	if (result.success) {
		expect(result.data.id).toBe(valid_uuid);
		expect(result.data.key).toBe(''); // Key should now be empty string
		expect(result.data.value).toBe('');
	}
});

test('Xml_Attribute - accepts objects with missing id and auto-generates it', () => {
	const invalid_attribute = {
		key: 'class',
		value: 'btn btn-primary',
	};

	const result = Xml_Attribute.safeParse(invalid_attribute);
	expect(result.success).toBe(true);
	if (result.success) {
		expect(result.data.id).toMatch(
			/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
		);
		expect(result.data.key).toBe('class');
		expect(result.data.value).toBe('btn btn-primary');
	}
});

test('Xml_Attribute - rejects objects with invalid id', () => {
	const invalid_attribute = {
		id: 'not-a-uuid',
		key: 'class',
		value: 'btn btn-primary',
	};

	const result = Xml_Attribute.safeParse(invalid_attribute);
	expect(result.success).toBe(false);
});

test('Xml_Attribute_Base - requires all properties without defaults', () => {
	const valid_uuid = '123e4567-e89b-12d3-a456-426614174000';

	// Valid full object
	const valid_result = Xml_Attribute_Base.safeParse({
		id: valid_uuid,
		key: 'class',
		value: 'btn',
	});
	expect(valid_result.success).toBe(true);

	// Missing key
	const missing_key_result = Xml_Attribute_Base.safeParse({
		id: valid_uuid,
		value: 'btn',
	} as any);
	expect(missing_key_result.success).toBe(false);

	// Missing value
	const missing_value_result = Xml_Attribute_Base.safeParse({
		id: valid_uuid,
		key: 'class',
	} as any);
	expect(missing_value_result.success).toBe(false);
});

test('Xml_Attribute_Base - rejects empty string key', () => {
	const valid_uuid = '123e4567-e89b-12d3-a456-426614174000';
	const attribute_with_empty_key = {
		id: valid_uuid,
		key: '',
		value: 'btn',
	};

	const result = Xml_Attribute_Base.safeParse(attribute_with_empty_key);
	expect(result.success).toBe(false);
});

// Integration tests
test('Xml_Attribute - integrates with other Zod schemas', () => {
	const Element = z.object({
		tag_name: z.string(),
		attributes: z.array(Xml_Attribute),
	});

	const valid_uuid = '123e4567-e89b-12d3-a456-426614174000';
	const valid_element = {
		tag_name: 'div',
		attributes: [
			{id: valid_uuid, key: 'class', value: 'container'},
			{id: '123e4567-e89b-12d3-a456-426614174001', key: 'id', value: 'main'},
		],
	};

	const result = Element.safeParse(valid_element);
	expect(result.success).toBe(true);
});

test('Xml_Attribute - works with nested structures', () => {
	const AttributeMap = z.record(z.string(), Xml_Attribute);

	const valid_uuid = '123e4567-e89b-12d3-a456-426614174000';
	const valid_map = {
		attr1: {id: valid_uuid, key: 'class', value: 'container'},
		attr2: {id: '123e4567-e89b-12d3-a456-426614174001', key: 'id', value: 'main'},
	};

	const result = AttributeMap.safeParse(valid_map);
	expect(result.success).toBe(true);
});

// Error message tests
test('Xml_Attribute - provides helpful error messages', () => {
	const invalid_attribute = {
		id: 'not-a-uuid',
		key: 'class',
		value: 'btn btn-primary',
	};

	const result = Xml_Attribute.safeParse(invalid_attribute);
	expect(result.success).toBe(false);
	if (!result.success) {
		expect(result.error.issues[0].path).toContain('id');
		expect(result.error.issues[0].message).toContain('uuid');
	}
});

// Performance considerations
test('Xml_Attribute - validation performance is reasonable', () => {
	const start_time = performance.now();
	const valid_uuid = '123e4567-e89b-12d3-a456-426614174000';

	// Validate 1000 attributes
	for (let i = 0; i < 1000; i++) {
		Xml_Attribute.safeParse({
			id: valid_uuid,
			key: 'class',
			value: 'btn',
		});
	}

	const end_time = performance.now();
	const duration = end_time - start_time;

	// Soft assertion - check that validation is not extremely slow
	expect(duration).toBeLessThan(1000); // Less than 1 second for 1000 validations
});

// Let's add a new test to clarify the behavior
test('Xml_Attribute with Uuid - allows id to be undefined and auto-generates it', () => {
	// undefined value is different from missing property
	// Properties must exist but can be undefined (which would trigger default)
	const obj_with_undefined_id = {
		id: undefined,
		key: 'class',
		value: 'button',
	};

	const result = Xml_Attribute.safeParse(obj_with_undefined_id);
	// This should now succeed because we use Uuid which has a default
	expect(result.success).toBe(true);
	if (result.success) {
		expect(result.data.id).toMatch(
			/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
		);
	}
});

// Add a new test to verify omitted id behavior
test('Xml_Attribute - auto-generates id when property is omitted', () => {
	const partial_attribute = {
		key: 'style',
		value: 'color: red',
	};

	const result = Xml_Attribute.safeParse(partial_attribute);
	expect(result.success).toBe(true);
	if (result.success) {
		expect(result.data.id).toMatch(
			/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
		);
		expect(result.data.key).toBe('style');
		expect(result.data.value).toBe('color: red');
	}
});

// Add new tests for empty value but defined key behavior
test('Xml_Attribute - accepts attribute with defined key and empty value', () => {
	const valid_uuid = '123e4567-e89b-12d3-a456-426614174000';
	const valid_attribute = {
		id: valid_uuid,
		key: 'disabled',
		value: '',
	};

	const result = Xml_Attribute.safeParse(valid_attribute);
	expect(result.success).toBe(true);
	if (result.success) {
		expect(result.data.id).toBe(valid_uuid);
		expect(result.data.key).toBe('disabled');
		expect(result.data.value).toBe('');
	}
});

test('Xml_Attribute - should be considered valid even when value is empty', () => {
	const valid_uuid = '123e4567-e89b-12d3-a456-426614174000';

	// Test with empty string value
	const attr_with_empty_value = {
		id: valid_uuid,
		key: 'required',
		value: '',
	};

	const result = Xml_Attribute.safeParse(attr_with_empty_value);
	expect(result.success).toBe(true);
	if (result.success) {
		expect(result.data.key).toBe('required');
		expect(result.data.value).toBe('');
	}
});

// Test for XML boolean attributes where value is intentionally empty
test('Xml_Attribute - supports boolean XML attributes with empty values', () => {
	const valid_uuid = '123e4567-e89b-12d3-a456-426614174000';
	const boolean_attributes = ['disabled', 'checked', 'readonly', 'required'];

	for (const attr_name of boolean_attributes) {
		const boolean_attr = {
			id: valid_uuid,
			key: attr_name,
			value: '',
		};

		const result = Xml_Attribute.safeParse(boolean_attr);
		expect(result.success).toBe(true);
		if (result.success) {
			expect(result.data.key).toBe(attr_name);
			expect(result.data.value).toBe('');
		}
	}
});

// Update to check that null keys are not accepted
test('Xml_Attribute - does not accept attributes with null keys', () => {
	const valid_uuid = '123e4567-e89b-12d3-a456-426614174000';
	const attr_with_null_key = {
		id: valid_uuid,
		key: null,
		value: 'test',
	};

	const result = Xml_Attribute.safeParse(attr_with_null_key);
	expect(result.success).toBe(false);
});
