// @slop Claude Sonnet 4

// @vitest-environment jsdom

import {describe, test, expect} from 'vitest';
import {z} from 'zod';

import {
	XmlAttributeKey,
	XmlAttributeKeyWithDefault,
	XmlAttributeValue,
	XmlAttributeValueWithDefault,
	XmlAttribute,
	XmlAttributeWithDefaults,
} from '$lib/xml.js';

// Test helpers
const uuid_regex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const test_uuid_a = '123e4567-e89b-12d3-a456-426614174000';

const expect_parse_success = <T>(schema: z.ZodType<T>, input: unknown, expected?: T) => {
	const result = schema.safeParse(input);
	expect(result.success).toBe(true);
	if (result.success && expected !== undefined) {
		expect(result.data).toEqual(expected);
	}
	return result.success ? result.data : undefined;
};

const expect_parse_failure = (schema: z.ZodType, input: unknown) => {
	const result = schema.safeParse(input);
	expect(result.success).toBe(false);
	return result.success ? undefined : result.error;
};

describe('XmlAttributeKey', () => {
	test('accepts valid attribute names', () => {
		const valid_keys = ['attr', 'data-test', 'xml:lang', 'ns:element', 'class'];
		for (const key of valid_keys) {
			expect_parse_success(XmlAttributeKey, key, key);
		}
	});

	test('trims whitespace', () => {
		expect_parse_success(XmlAttributeKey, '  attr  ', 'attr');
		expect_parse_success(XmlAttributeKey, '\t class \n', 'class');
	});

	test('rejects empty strings after trimming', () => {
		expect_parse_failure(XmlAttributeKey, '');
		expect_parse_failure(XmlAttributeKey, '   ');
		expect_parse_failure(XmlAttributeKey, '\t\n');
	});

	test('rejects non-strings', () => {
		expect_parse_failure(XmlAttributeKey, null);
		expect_parse_failure(XmlAttributeKey, undefined);
		expect_parse_failure(XmlAttributeKey, 123);
		expect_parse_failure(XmlAttributeKey, {});
	});

	test('handles special characters', () => {
		expect_parse_success(XmlAttributeKey, 'data-123');
		expect_parse_success(XmlAttributeKey, 'xml_test');
		expect_parse_success(XmlAttributeKey, 'attr.value');
	});

	test('handles unicode', () => {
		expect_parse_success(XmlAttributeKey, 'атрибут');
		expect_parse_success(XmlAttributeKey, '属性');
	});
});

describe('XmlAttributeKeyWithDefault', () => {
	test('provides default value', () => {
		expect_parse_success(XmlAttributeKeyWithDefault, undefined, 'attr');
	});

	test('accepts valid strings', () => {
		expect_parse_success(XmlAttributeKeyWithDefault, 'custom', 'custom');
	});

	test('rejects empty strings', () => {
		expect_parse_failure(XmlAttributeKeyWithDefault, '');
		expect_parse_failure(XmlAttributeKeyWithDefault, '   ');
	});
});

describe('XmlAttributeValue', () => {
	test('accepts any string', () => {
		const values = ['', 'text', '123', 'true', 'special chars: <>&"\''];
		for (const value of values) {
			expect_parse_success(XmlAttributeValue, value, value);
		}
	});

	test('accepts unicode', () => {
		expect_parse_success(XmlAttributeValue, '测试值');
		expect_parse_success(XmlAttributeValue, 'значение');
		expect_parse_success(XmlAttributeValue, '🔥💯');
	});

	test('accepts very long strings', () => {
		const long_value = 'a'.repeat(10000);
		expect_parse_success(XmlAttributeValue, long_value, long_value);
	});

	test('rejects non-strings', () => {
		expect_parse_failure(XmlAttributeValue, null);
		expect_parse_failure(XmlAttributeValue, undefined);
		expect_parse_failure(XmlAttributeValue, 123);
		expect_parse_failure(XmlAttributeValue, []);
	});
});

describe('XmlAttributeValueWithDefault', () => {
	test('provides empty string default', () => {
		expect_parse_success(XmlAttributeValueWithDefault, undefined, '');
	});

	test('accepts valid strings', () => {
		expect_parse_success(XmlAttributeValueWithDefault, 'test', 'test');
	});
});

describe('XmlAttribute', () => {
	const valid_base_attr = {
		id: test_uuid_a,
		key: 'class',
		value: 'container',
	};

	test('accepts complete valid attributes', () => {
		expect_parse_success(XmlAttribute, valid_base_attr);
	});

	test('requires all properties', () => {
		expect_parse_failure(XmlAttribute, {id: test_uuid_a, key: 'class'});
		expect_parse_failure(XmlAttribute, {id: test_uuid_a, value: 'test'});
		expect_parse_failure(XmlAttribute, {key: 'class', value: 'test'});
	});

	test('validates uuid format', () => {
		expect_parse_failure(XmlAttribute, {...valid_base_attr, id: 'invalid-uuid'});
		expect_parse_failure(XmlAttribute, {...valid_base_attr, id: ''});
	});

	test('validates key constraints', () => {
		expect_parse_failure(XmlAttribute, {...valid_base_attr, key: ''});
		expect_parse_failure(XmlAttribute, {...valid_base_attr, key: '   '});
	});

	test('strict mode rejects extra properties', () => {
		const attr_with_extra = {...valid_base_attr, extra: 'property'};
		expect_parse_failure(XmlAttribute, attr_with_extra);
	});

	test('accepts empty values', () => {
		expect_parse_success(XmlAttribute, {...valid_base_attr, value: ''});
	});
});

describe('XmlAttributeWithDefaults', () => {
	test('accepts complete attributes', () => {
		const attr = {id: test_uuid_a, key: 'id', value: 'main'};
		expect_parse_success(XmlAttributeWithDefaults, attr);
	});

	test('generates uuid when missing', () => {
		const attr_no_id = {key: 'class', value: 'test'};
		const result = expect_parse_success(XmlAttributeWithDefaults, attr_no_id);
		expect(result?.id).toMatch(uuid_regex);
	});

	test('applies key default when missing', () => {
		const attr_no_key = {id: test_uuid_a, value: 'test'};
		const result = expect_parse_success(XmlAttributeWithDefaults, attr_no_key);
		expect(result?.key).toBe('attr');
	});

	test('applies value default when missing', () => {
		const attr_no_value = {id: test_uuid_a, key: 'disabled'};
		const result = expect_parse_success(XmlAttributeWithDefaults, attr_no_value);
		expect(result?.value).toBe('');
	});

	test('applies all defaults when minimal input', () => {
		const result = expect_parse_success(XmlAttributeWithDefaults, {});
		expect(result?.id).toMatch(uuid_regex);
		expect(result?.key).toBe('attr');
		expect(result?.value).toBe('');
	});

	test('handles undefined id explicitly', () => {
		const attr = {id: undefined, key: 'test', value: 'value'};
		const result = expect_parse_success(XmlAttributeWithDefaults, attr);
		expect(result?.id).toMatch(uuid_regex);
	});

	test('strict mode rejects extra properties', () => {
		const attr_with_extra = {id: test_uuid_a, key: 'test', value: 'val', extra: 'prop'};
		expect_parse_failure(XmlAttributeWithDefaults, attr_with_extra);
	});

	test('validates constraints after applying defaults', () => {
		const attr_empty_key = {id: test_uuid_a, key: '', value: 'test'};
		expect_parse_failure(XmlAttributeWithDefaults, attr_empty_key);
	});
});

describe('XML use cases', () => {
	test('boolean attributes with empty values', () => {
		const boolean_attrs = ['disabled', 'checked', 'selected', 'hidden'];
		for (const key of boolean_attrs) {
			const attr = {id: test_uuid_a, key, value: ''};
			expect_parse_success(XmlAttributeWithDefaults, attr);
		}
	});

	test('namespace prefixed attributes', () => {
		const ns_attrs = ['xml:lang', 'xmlns:foo', 'xsi:type', 'data:custom'];
		for (const key of ns_attrs) {
			const attr = {id: test_uuid_a, key, value: 'test'};
			expect_parse_success(XmlAttributeWithDefaults, attr);
		}
	});

	test('complex attribute values', () => {
		const complex_values = [
			'rgb(255, 0, 0)',
			'url(#gradient)',
			'calc(100% - 20px)',
			'{"key": "value"}',
		];
		for (const value of complex_values) {
			const attr = {id: test_uuid_a, key: 'style', value};
			expect_parse_success(XmlAttributeWithDefaults, attr);
		}
	});

	test('integration with array of attributes', () => {
		const AttributeArray = z.array(XmlAttributeWithDefaults);
		const attrs = [
			{key: 'class', value: 'container'},
			{key: 'id', value: 'main'},
		];
		const result = expect_parse_success(AttributeArray, attrs);
		expect(result).toHaveLength(2);
		const first_attr = result?.[0];
		const second_attr = result?.[1];
		expect(first_attr).toBeDefined();
		expect(second_attr).toBeDefined();
		expect(first_attr!.id).toMatch(uuid_regex);
		expect(second_attr!.id).toMatch(uuid_regex);
	});

	test('integration with record of attributes', () => {
		const AttributeRecord = z.record(z.string(), XmlAttributeWithDefaults);
		const attrs = {
			class_attr: {key: 'class', value: 'container'},
			id_attr: {key: 'id', value: 'main'},
		};
		expect_parse_success(AttributeRecord, attrs);
	});
});

describe('error handling', () => {
	test('provides meaningful error messages', () => {
		const invalid_attr = {id: 'not-uuid', key: '', value: 123};
		const error = expect_parse_failure(XmlAttributeWithDefaults, invalid_attr);

		const issue_paths = error?.issues.map((i) => i.path.join('.')) || [];
		expect(issue_paths).toContain('id');
		expect(issue_paths).toContain('key');
		expect(issue_paths).toContain('value');
	});

	test('handles type coercion failures gracefully', () => {
		expect_parse_failure(XmlAttributeWithDefaults, null);
		expect_parse_failure(XmlAttributeWithDefaults, 'string');
		expect_parse_failure(XmlAttributeWithDefaults, []);
	});
});
