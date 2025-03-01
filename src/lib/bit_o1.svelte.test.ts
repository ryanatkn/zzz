import {test} from 'uvu';
import * as assert from 'uvu/assert';

import {Bit} from '$lib/bit.svelte.js';
import {Uuid} from '$lib/uuid.js';

/**
 * Constructor & defaults
 */
test('constructor - no input (all defaults)', () => {
	const bit = new Bit();

	assert.ok(bit.id, 'Bit should have a generated id');
	assert.type(bit.name, 'string');
	assert.is(bit.name, '', 'Default name is empty string');
	assert.is(bit.has_xml_tag, false, 'Default has_xml_tag is false');
	assert.is(bit.xml_tag_name, '', 'Default xml_tag_name is empty string');
	assert.ok(Array.isArray(bit.attributes), 'attributes is an array by default');
	assert.is(bit.attributes.length, 0, 'Default attributes array is empty');
	assert.is(bit.enabled, true, 'Default enabled is true');
	assert.is(bit.content, '', 'Default content is empty string');
	assert.is(bit.length, 0, 'Length is 0 for empty content');
	assert.ok(Array.isArray(bit.tokens), 'Tokens should be an array');
	assert.is(bit.tokens.length, 0, 'Tokens array is empty for empty content');
	assert.is(bit.token_count, 0, 'Token count is 0 for empty content');
});

test('constructor - partial input (some fields missing)', () => {
	const bit = new Bit({
		json: {
			name: 'partial_a',
			content: 'partial_b',
			// everything else left out
		},
	});

	assert.ok(bit.id, 'Bit should have a generated id when id is not provided');
	assert.is(bit.name, 'partial_a');
	assert.is(bit.content, 'partial_b');
	assert.is(bit.has_xml_tag, false, 'Default has_xml_tag is false if not provided');
	assert.is(bit.xml_tag_name, '', 'Default xml_tag_name is empty string if not provided');
	assert.is(bit.enabled, true, 'Default enabled is true if not provided');
	assert.is(bit.attributes.length, 0, 'No attributes provided -> empty array');
});

test('constructor - full input (all fields)', () => {
	const preDefinedId = Uuid.parse(undefined);
	const bit = new Bit({
		json: {
			id: preDefinedId,
			name: 'full_a',
			has_xml_tag: true,
			xml_tag_name: 'tag_a',
			attributes: [
				{id: Uuid.parse(undefined), key: 'k1', value: 'v1'},
				{id: Uuid.parse(undefined), key: 'k2', value: 'v2'},
			],
			enabled: false,
			content: 'some_content_a',
		},
	});

	assert.is(bit.id, preDefinedId, 'Should match the provided id');
	assert.is(bit.name, 'full_a');
	assert.is(bit.has_xml_tag, true);
	assert.is(bit.xml_tag_name, 'tag_a');
	assert.is(bit.attributes.length, 2, 'Should have 2 attributes');
	assert.is(bit.enabled, false);
	assert.is(bit.content, 'some_content_a');
	assert.is(bit.length, 14, 'Length of "some_content_a" is 14');
	assert.ok(
		bit.token_count >= 1,
		'Token count should be >= 1 for non-empty text (depends on tokenizer specifics)',
	);
});

/**
 * from_json() static method
 */
test('from_json - no input (all defaults)', () => {
	const bit = Bit.from_json();
	assert.is(bit.name, '');
	assert.is(bit.content, '');
});

test('from_json - partial input (some fields)', () => {
	const bit = Bit.from_json({
		name: 'x_a',
		content: 'x_b',
	});
	assert.is(bit.name, 'x_a');
	assert.is(bit.content, 'x_b');
});

test('from_json - invalid input (should throw)', () => {
	try {
		// Passing a boolean to 'name' which violates the zod schema for strings
		Bit.from_json({
			name: true as unknown as string,
		});
		assert.unreachable('Expected an error to be thrown');
	} catch (e) {
		assert.ok(e instanceof Error, 'Should throw a ZodError or a parsing Error');
	}
});

/**
 * set_json() method
 */
test('set_json - partial input updates fields', () => {
	const bit = new Bit();

	bit.set_json({
		name: 'setjson_a',
		content: 'setjson_b',
		has_xml_tag: true,
		xml_tag_name: 'tag_x',
	});

	assert.is(bit.name, 'setjson_a');
	assert.is(bit.content, 'setjson_b');
	assert.is(bit.has_xml_tag, true);
	assert.is(bit.xml_tag_name, 'tag_x');
	// unchanged fields remain defaults
	assert.is(bit.attributes.length, 0);
	assert.is(bit.enabled, true);
});

test('set_json - invalid input (should throw)', () => {
	const bit = new Bit();
	try {
		// Passing a number to 'name' which is invalid per schema
		bit.set_json({
			name: 123 as unknown as string,
		});
		assert.unreachable('Expected an error to be thrown due to invalid data');
	} catch (e) {
		assert.ok(e instanceof Error, 'Should throw a ZodError or a parsing Error');
	}
});

/**
 * Attribute methods: add, update, remove
 */
test('add_attribute - minimal input (generates defaults)', () => {
	const bit = new Bit();
	assert.is(bit.attributes.length, 0);

	bit.add_attribute({key: 'a1', value: 'b1'});
	assert.is(bit.attributes.length, 1);

	const attr = bit.attributes[0];
	assert.is(attr.key, 'a1');
	assert.is(attr.value, 'b1');
	assert.ok(attr.id, 'Attribute should have a generated id');
});

test('update_attribute - existing attribute', () => {
	const bit = new Bit({
		json: {
			attributes: [{id: Uuid.parse(undefined), key: 'key_1', value: 'value_1'}],
		},
	});

	const existingId = bit.attributes[0].id;
	const didUpdate = bit.update_attribute(existingId, {value: 'value_1_updated'});
	assert.is(didUpdate, true, 'Should return true if attribute was updated');
	assert.is(bit.attributes[0].value, 'value_1_updated', 'Attribute value should be updated');
});

test('update_attribute - non-existing attribute', () => {
	const bit = new Bit({
		json: {
			attributes: [{id: Uuid.parse(undefined), key: 'key_1', value: 'value_1'}],
		},
	});

	const randomId = Uuid.parse(undefined);
	const didUpdate = bit.update_attribute(randomId, {value: 'new_val'});
	assert.is(didUpdate, false, 'Should return false if attribute was not found');
	assert.is(bit.attributes[0].value, 'value_1', 'Existing attribute remains unchanged');
});

test('remove_attribute - existing attribute', () => {
	const existingId = Uuid.parse(undefined);
	const bit = new Bit({
		json: {
			attributes: [
				{id: existingId, key: 'k1', value: 'v1'},
				{id: Uuid.parse(undefined), key: 'k2', value: 'v2'},
			],
		},
	});
	assert.is(bit.attributes.length, 2);

	bit.remove_attribute(existingId);
	assert.is(bit.attributes.length, 1, 'One attribute should be removed');
	assert.is(bit.attributes[0].key, 'k2', 'Remaining attribute is the second one');
});

test('remove_attribute - non-existing attribute', () => {
	const bit = new Bit({
		json: {
			attributes: [{id: Uuid.parse(undefined), key: 'k1', value: 'v1'}],
		},
	});
	assert.is(bit.attributes.length, 1);

	const randomId = Uuid.parse(undefined);
	bit.remove_attribute(randomId);
	assert.is(bit.attributes.length, 1, 'Attribute list remains unchanged');
});

/**
 * Derived properties
 */
test('derived properties - length, tokens, token_count', () => {
	const bit = new Bit({
		json: {
			content: 'abc',
		},
	});
	assert.is(bit.length, 3, 'Length of "abc" is 3');
	assert.ok(Array.isArray(bit.tokens), 'tokens should be an array');
	assert.ok(bit.tokens.length > 0, 'tokens should not be empty for "abc"');
	assert.is(bit.token_count, bit.tokens.length, 'token_count should match tokens array length');
});

/**
 * clone() tests - existing
 */
test('clone() - returns a new Bit instance', () => {
	const original = new Bit({
		json: {
			id: Uuid.parse(undefined),
			name: 'Test Bit',
			content: 'Some content',
			attributes: [],
		},
	});

	const clone = original.clone();

	// Verify it's a Bit instance
	assert.instance(clone, Bit);

	// Verify it's not the same object reference
	assert.is.not(clone, original);

	// Verify the properties are the same
	assert.equal(clone.id, original.id);
	assert.equal(clone.name, original.name);
	assert.equal(clone.content, original.content);
	assert.equal(clone.attributes, clone.attributes);
	assert.is.not(clone.attributes, clone.attributes);
});

test('clone() - mutations to clone do not affect original', () => {
	const original = new Bit({
		json: {
			id: Uuid.parse(undefined),
			name: 'Original name',
			content: 'Original content',
		},
	});

	const clone = original.clone();

	// Modify the clone
	clone.name = 'Modified name';
	clone.content = 'Modified content';

	// Original should remain unchanged
	assert.equal(original.name, 'Original name');
	assert.equal(original.content, 'Original content');

	// Clone should have new values
	assert.equal(clone.name, 'Modified name');
	assert.equal(clone.content, 'Modified content');
});

test('clone() - attributes are cloned correctly', () => {
	const original = new Bit({
		json: {
			id: Uuid.parse(undefined),
			name: 'Bit with attributes',
			has_xml_tag: true,
			xml_tag_name: 'test',
			attributes: [
				{id: Uuid.parse(undefined), key: 'attr1', value: 'value1'},
				{id: Uuid.parse(undefined), key: 'attr2', value: 'value2'},
			],
		},
	});

	const clone = original.clone();

	// Verify attributes are cloned
	assert.equal(clone.attributes.length, original.attributes.length);
	assert.equal(clone.attributes[0].key, original.attributes[0].key);
	assert.equal(clone.attributes[0].value, original.attributes[0].value);

	// Modify clone's attributes
	clone.attributes[0].value = 'modified';

	// Original should be unchanged
	assert.equal(original.attributes[0].value, 'value1');
	assert.equal(clone.attributes[0].value, 'modified');
});

test.run();
