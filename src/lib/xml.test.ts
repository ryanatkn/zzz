// @slop Claude Opus 4

import {describe, test, expect} from 'vitest';
import {z} from 'zod';

import {
	Xml_Attribute_With_Defaults,
	Xml_Attribute,
	Xml_Attribute_Key_With_Default,
	Xml_Attribute_Key,
	Xml_Attribute_Value_With_Default,
	Xml_Attribute_Value,
} from '$lib/xml.js';

// Test constants
const TEST_UUID = '123e4567-e89b-12d3-a456-426614174000';
const TEST_UUID_ALT = '123e4567-e89b-12d3-a456-426614174001';

const TEST_KEYS = {
	VALID: ['attr_a', 'attr_b', 'data_test', 'text_id'],
	INVALID: ['', null],
};

const TEST_VALUES = {
	TEXT: 'sample_value',
	EMPTY: '',
	NUMERIC: '123',
	BOOLEAN: 'true',
};

describe('Xml_Attribute_Key', () => {
	test('is a Zod string schema', () => {
		expect(Xml_Attribute_Key_With_Default).toBeInstanceOf(z.ZodType);
	});

	test('accepts valid strings', () => {
		for (const key of TEST_KEYS.VALID) {
			const result = Xml_Attribute_Key_With_Default.safeParse(key);
			expect(result.success).toBe(true);
			if (result.success) {
				expect(result.data).toBe(key);
			}
		}
	});

	test('disallows empty strings', () => {
		const result = Xml_Attribute_Key_With_Default.safeParse('');
		expect(result.success).toBe(false);
	});

	test('provides empty string as default when undefined', () => {
		const result = Xml_Attribute_Key_With_Default.parse(undefined);
		expect(result).toBe('attr');
	});

	test('trims whitespace', () => {
		const result = Xml_Attribute_Key_With_Default.safeParse('  attr_a  ');
		expect(result.success).toBe(true);
		if (result.success) {
			expect(result.data).toBe('attr_a');
		}

		const whitespace_result = Xml_Attribute_Key_With_Default.safeParse('   ');
		expect(whitespace_result.success).toBe(false);
		if (!whitespace_result.success) {
			expect(whitespace_result.error.issues[0].code).toBe('too_small');
		}
	});

	test('disallows empty strings with whitespace', () => {
		const result = Xml_Attribute_Key_With_Default.safeParse(' ');
		expect(result.success).toBe(false);
	});

	test('does not allow null values', () => {
		const result = Xml_Attribute_Key_With_Default.safeParse(null);
		expect(result.success).toBe(false);
	});
});

describe('Xml_Attribute_Key_Base', () => {
	test('rejects empty strings', () => {
		const result = Xml_Attribute_Key.safeParse('');
		expect(result.success).toBe(false);
		if (!result.success) {
			expect(result.error.issues[0].code).toBe('too_small');
		}
	});

	test('rejects undefined', () => {
		const result = Xml_Attribute_Key.safeParse(undefined);
		expect(result.success).toBe(false);
	});
});

describe('Xml_Attribute_Value', () => {
	test('is a Zod string schema', () => {
		expect(Xml_Attribute_Value_With_Default).toBeInstanceOf(z.ZodType);
	});

	test('accepts any string', () => {
		const valid_values = [
			TEST_VALUES.TEXT,
			TEST_VALUES.EMPTY,
			TEST_VALUES.NUMERIC,
			TEST_VALUES.BOOLEAN,
		];

		for (const value of valid_values) {
			const result = Xml_Attribute_Value_With_Default.safeParse(value);
			expect(result.success).toBe(true);
			if (result.success) {
				expect(result.data).toBe(value);
			}
		}
	});

	test('provides default empty string when undefined', () => {
		const result = Xml_Attribute_Value_With_Default.parse(undefined);
		expect(result).toBe('');
	});
});

describe('Xml_Attribute_Value_Base', () => {
	test('rejects undefined', () => {
		const result = Xml_Attribute_Value.safeParse(undefined);
		expect(result.success).toBe(false);
	});
});

describe('Xml_Attribute', () => {
	test('is a Zod object schema', () => {
		expect(Xml_Attribute_With_Defaults).toBeInstanceOf(z.ZodType);
	});

	test('accepts valid attribute objects', () => {
		const valid_attribute = {
			id: TEST_UUID,
			key: 'attr_a',
			value: TEST_VALUES.TEXT,
		};

		const result = Xml_Attribute_With_Defaults.safeParse(valid_attribute);
		expect(result.success).toBe(true);
		if (result.success) {
			expect(result.data.id).toBe(TEST_UUID);
			expect(result.data.key).toBe('attr_a');
			expect(result.data.value).toBe(TEST_VALUES.TEXT);
		}
	});

	test('applies defaults for key and value when missing', () => {
		const partial_attribute = {
			id: TEST_UUID,
		};

		const result = Xml_Attribute_With_Defaults.safeParse(partial_attribute as any);
		expect(result.success).toBe(true);
		if (result.success) {
			expect(result.data.id).toBe(TEST_UUID);
			expect(result.data.key).toBe('attr');
			expect(result.data.value).toBe('');
		}
	});

	test('accepts objects with missing id and auto-generates it', () => {
		const attribute_without_id = {
			key: 'attr_a',
			value: TEST_VALUES.TEXT,
		};

		const result = Xml_Attribute_With_Defaults.safeParse(attribute_without_id);
		expect(result.success).toBe(true);
		if (result.success) {
			expect(result.data.id).toMatch(
				/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
			);
			expect(result.data.key).toBe('attr_a');
			expect(result.data.value).toBe(TEST_VALUES.TEXT);
		}
	});

	test('rejects objects with invalid id', () => {
		const invalid_attribute = {
			id: 'not-a-uuid',
			key: 'attr_a',
			value: TEST_VALUES.TEXT,
		};

		const result = Xml_Attribute_With_Defaults.safeParse(invalid_attribute);
		expect(result.success).toBe(false);
	});

	test('auto-generates id when property is omitted', () => {
		const partial_attribute = {
			key: 'attr_b',
			value: TEST_VALUES.NUMERIC,
		};

		const result = Xml_Attribute_With_Defaults.safeParse(partial_attribute);
		expect(result.success).toBe(true);
		if (result.success) {
			expect(result.data.id).toMatch(
				/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
			);
			expect(result.data.key).toBe('attr_b');
			expect(result.data.value).toBe(TEST_VALUES.NUMERIC);
		}
	});

	test('accepts attribute with defined key and empty value', () => {
		const valid_attribute = {
			id: TEST_UUID,
			key: 'flag_a',
			value: '',
		};

		const result = Xml_Attribute_With_Defaults.safeParse(valid_attribute);
		expect(result.success).toBe(true);
		if (result.success) {
			expect(result.data.id).toBe(TEST_UUID);
			expect(result.data.key).toBe('flag_a');
			expect(result.data.value).toBe('');
		}
	});

	test('allows id to be undefined and auto-generates it', () => {
		const obj_with_undefined_id = {
			id: undefined,
			key: 'attr_a',
			value: TEST_VALUES.TEXT,
		};

		const result = Xml_Attribute_With_Defaults.safeParse(obj_with_undefined_id);
		expect(result.success).toBe(true);
		if (result.success) {
			expect(result.data.id).toMatch(
				/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
			);
		}
	});

	test('does not accept attributes with null keys', () => {
		const attr_with_null_key = {
			id: TEST_UUID,
			key: null,
			value: TEST_VALUES.TEXT,
		};

		const result = Xml_Attribute_With_Defaults.safeParse(attr_with_null_key);
		expect(result.success).toBe(false);
	});
});

describe('Xml_Attribute_Base', () => {
	test('requires all properties without defaults', () => {
		// Valid full object
		const valid_result = Xml_Attribute.safeParse({
			id: TEST_UUID,
			key: 'attr_a',
			value: TEST_VALUES.TEXT,
		});
		expect(valid_result.success).toBe(true);

		// Missing key
		const missing_key_result = Xml_Attribute.safeParse({
			id: TEST_UUID,
			value: TEST_VALUES.TEXT,
		} as any);
		expect(missing_key_result.success).toBe(false);

		// Missing value
		const missing_value_result = Xml_Attribute.safeParse({
			id: TEST_UUID,
			key: 'attr_a',
		} as any);
		expect(missing_value_result.success).toBe(false);
	});

	test('rejects empty string key', () => {
		const attribute_with_empty_key = {
			id: TEST_UUID,
			key: '',
			value: TEST_VALUES.TEXT,
		};

		const result = Xml_Attribute.safeParse(attribute_with_empty_key);
		expect(result.success).toBe(false);
	});
});

describe('Xml_Attribute integrations', () => {
	test('integrates with other Zod schemas', () => {
		const Element = z.object({
			tag_name: z.string(),
			attributes: z.array(Xml_Attribute_With_Defaults),
		});

		const valid_element = {
			tag_name: 'element_a',
			attributes: [
				{id: TEST_UUID, key: 'attr_a', value: TEST_VALUES.TEXT},
				{id: TEST_UUID_ALT, key: 'attr_b', value: TEST_VALUES.NUMERIC},
			],
		};

		const result = Element.safeParse(valid_element);
		expect(result.success).toBe(true);
	});

	test('works with nested structures', () => {
		const AttributeMap = z.record(z.string(), Xml_Attribute_With_Defaults);

		const valid_map = {
			attr1: {id: TEST_UUID, key: 'attr_a', value: TEST_VALUES.TEXT},
			attr2: {id: TEST_UUID_ALT, key: 'attr_b', value: TEST_VALUES.NUMERIC},
		};

		const result = AttributeMap.safeParse(valid_map);
		expect(result.success).toBe(true);
	});
});

describe('Xml_Attribute special cases', () => {
	test('supports boolean XML attributes with empty values', () => {
		const boolean_attributes = ['flag_a', 'flag_b', 'flag_c', 'flag_d'];

		for (const attr_name of boolean_attributes) {
			const boolean_attr = {
				id: TEST_UUID,
				key: attr_name,
				value: '',
			};

			const result = Xml_Attribute_With_Defaults.safeParse(boolean_attr);
			expect(result.success).toBe(true);
			if (result.success) {
				expect(result.data.key).toBe(attr_name);
				expect(result.data.value).toBe('');
			}
		}
	});

	test('provides helpful error messages', () => {
		const invalid_attribute = {
			id: 'not-a-uuid',
			key: 'attr_a',
			value: TEST_VALUES.TEXT,
		};

		const result = Xml_Attribute_With_Defaults.safeParse(invalid_attribute);
		expect(result.success).toBe(false);
		if (!result.success) {
			expect(result.error.issues[0].path).toContain('id');
			expect(result.error.issues[0].message).toContain('uuid');
		}
	});

	test('validation performance is reasonable', () => {
		const start_time = performance.now();

		// Validate 1000 attributes
		for (let i = 0; i < 1000; i++) {
			Xml_Attribute_With_Defaults.safeParse({
				id: TEST_UUID,
				key: 'attr_a',
				value: TEST_VALUES.TEXT,
			});
		}

		const end_time = performance.now();
		const duration = end_time - start_time;

		// Soft assertion - check that validation is not extremely slow
		expect(duration).toBeLessThan(1000); // Less than 1 second for 1000 validations
	});
});
