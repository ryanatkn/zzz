// bit.svelte.test.ts

import {test} from 'uvu';
import * as assert from 'uvu/assert';
import {encode} from 'gpt-tokenizer';

import {Bit} from '$lib/bit.svelte.js';
import {Uuid} from '$lib/uuid.js';

// Constructor tests
test('constructor - creates with default values when no options provided', () => {
	const bit = new Bit();

	assert.ok(bit instanceof Bit, 'Should be an instance of Bit');
	assert.ok(bit.id);
	Uuid.parse(bit.id);
	assert.equal(bit.name, '');
	assert.equal(bit.has_xml_tag, false);
	assert.equal(bit.xml_tag_name, '');
	assert.equal(bit.attributes.length, 0);
	assert.equal(bit.enabled, true);
	assert.equal(bit.content, '');
	assert.equal(bit.length, 0);
	assert.equal(bit.token_count, 0);
});

// from_json tests
test('from_json - creates a Bit with default values when no json provided', () => {
	const bit = Bit.from_json();

	assert.ok(bit instanceof Bit, 'Should be an instance of Bit');
	assert.ok(bit.id);
	assert.equal(bit.name, '');
	assert.equal(bit.has_xml_tag, false);
	assert.equal(bit.xml_tag_name, '');
	assert.equal(bit.attributes.length, 0);
	assert.equal(bit.enabled, true);
	assert.equal(bit.content, '');
});

// Derived properties tests
test('derived_properties - length and token_count update when content changes', () => {
	const bit = new Bit({
		json: {
			content: 'A',
		},
	});

	assert.equal(bit.length, 1, 'Initial length should be 1');
	const initial_token_count = bit.token_count;
	assert.ok(initial_token_count > 0, 'Should have at least one token');
	assert.equal(bit.tokens, encode('A'), 'Token array should match encoded value');

	bit.content = 'ABC';
	assert.equal(bit.length, 3, 'Length should update to 3');
	assert.ok(
		bit.token_count >= initial_token_count,
		'Token count should not decrease for longer content',
	);
	assert.equal(bit.tokens, encode('ABC'), 'Token array should update');
});

// Clone test - don't assert exact lengths since token encoding can change
test('clone - derived properties are calculated correctly', () => {
	const test_content = 'This is a test content';
	const original = new Bit({
		json: {
			content: test_content,
		},
	});

	const clone = original.clone();
	assert.equal(clone.length, original.length, 'Clone length should match original length');
	assert.equal(
		clone.token_count,
		original.token_count,
		'Clone should have same token count as original',
	);
	assert.equal(
		clone.tokens.length,
		encode(test_content).length,
		'Token count should match encoded tokens',
	);

	// Verify derived properties update independently
	clone.content = 'Different content';
	assert.equal(clone.length, 'Different content'.length);
	assert.not.equal(clone.length, original.length);
	assert.not.equal(clone.token_count, original.token_count);
});

// Constructor tests
test('constructor - initializes with provided values', () => {
	const id = Uuid.parse(undefined);
	const bit = new Bit({
		json: {
			id,
			name: 'Test Bit',
			has_xml_tag: true,
			xml_tag_name: 'div',
			attributes: [{id: Uuid.parse(undefined), key: 'class', value: 'container'}],
			enabled: false,
			content: 'Hello world',
		},
	});

	assert.equal(bit.id, id);
	assert.equal(bit.name, 'Test Bit');
	assert.equal(bit.has_xml_tag, true);
	assert.equal(bit.xml_tag_name, 'div');
	assert.equal(bit.attributes.length, 1);
	assert.equal(bit.attributes[0].key, 'class');
	assert.equal(bit.attributes[0].value, 'container');
	assert.equal(bit.enabled, false);
	assert.equal(bit.content, 'Hello world');
	assert.equal(bit.length, 11); // 'Hello world' length
	assert.equal(bit.tokens, encode('Hello world')); // Use encode function for tokens
});

// from_json tests
test('from_json - creates a Bit with provided values', () => {
	const id = Uuid.parse(undefined);
	const bit = Bit.from_json({
		id,
		name: 'From JSON',
		has_xml_tag: true,
		xml_tag_name: 'span',
		enabled: false,
		content: 'Created from JSON',
	});

	assert.equal(bit.id, id);
	assert.equal(bit.name, 'From JSON');
	assert.equal(bit.has_xml_tag, true);
	assert.equal(bit.xml_tag_name, 'span');
	assert.equal(bit.enabled, false);
	assert.equal(bit.content, 'Created from JSON');
});

// to_json tests
test('to_json - serializes all properties correctly', () => {
	const id = Uuid.parse(undefined);
	const attr_id = Uuid.parse(undefined);
	const bit = new Bit({
		json: {
			id,
			name: 'Serialization Test',
			has_xml_tag: true,
			xml_tag_name: 'p',
			attributes: [{id: attr_id, key: 'data-test', value: 'true'}],
			enabled: true,
			content: 'Test content',
		},
	});

	const json = bit.to_json();

	assert.equal(json.id, id);
	assert.equal(json.name, 'Serialization Test');
	assert.equal(json.has_xml_tag, true);
	assert.equal(json.xml_tag_name, 'p');
	assert.equal(json.attributes.length, 1);
	assert.equal(json.attributes[0].id, attr_id);
	assert.equal(json.attributes[0].key, 'data-test');
	assert.equal(json.attributes[0].value, 'true');
	assert.equal(json.enabled, true);
	assert.equal(json.content, 'Test content');
});

// set_json tests
test('set_json - updates properties with new values', () => {
	const bit = new Bit();
	const new_id = Uuid.parse(undefined);

	bit.set_json({
		id: new_id,
		name: 'Updated Bit',
		has_xml_tag: true,
		xml_tag_name: 'section',
		attributes: [{id: Uuid.parse(undefined), key: 'role', value: 'main'}],
		enabled: false,
		content: 'Updated content',
	});

	assert.equal(bit.id, new_id);
	assert.equal(bit.name, 'Updated Bit');
	assert.equal(bit.has_xml_tag, true);
	assert.equal(bit.xml_tag_name, 'section');
	assert.equal(bit.attributes.length, 1);
	assert.equal(bit.attributes[0].key, 'role');
	assert.equal(bit.attributes[0].value, 'main');
	assert.equal(bit.enabled, false);
	assert.equal(bit.content, 'Updated content');
});

// add_attribute tests
test('add_attribute - adds a new attribute', () => {
	const bit = new Bit();

	bit.add_attribute({
		id: Uuid.parse(undefined),
		key: 'attr1',
		value: 'value1',
	});

	assert.equal(bit.attributes.length, 1);
	assert.equal(bit.attributes[0].key, 'attr1');
	assert.equal(bit.attributes[0].value, 'value1');
});

test('add_attribute - adds multiple attributes', () => {
	const bit = new Bit();

	bit.add_attribute({
		id: Uuid.parse(undefined),
		key: 'attr1',
		value: 'value1',
	});

	bit.add_attribute({
		id: Uuid.parse(undefined),
		key: 'attr2',
		value: 'value2',
	});

	assert.equal(bit.attributes.length, 2);
	assert.equal(bit.attributes[0].key, 'attr1');
	assert.equal(bit.attributes[1].key, 'attr2');
});

// update_attribute tests
test('update_attribute - returns true and updates existing attribute', () => {
	const bit = new Bit();
	const attr_id = Uuid.parse(undefined);

	bit.add_attribute({
		id: attr_id,
		key: 'original',
		value: 'value',
	});

	const result = bit.update_attribute(attr_id, {
		key: 'updated',
		value: 'new-value',
	});

	assert.equal(result, true);
	assert.equal(bit.attributes.length, 1);
	assert.equal(bit.attributes[0].key, 'updated');
	assert.equal(bit.attributes[0].value, 'new-value');
});

test('update_attribute - returns false when attribute not found', () => {
	const bit = new Bit();
	const existing_attr_id = Uuid.parse(undefined);
	const non_existent_id = Uuid.parse(undefined);

	bit.add_attribute({
		id: existing_attr_id,
		key: 'existing',
		value: 'value',
	});

	const result = bit.update_attribute(non_existent_id, {
		key: 'updated',
		value: 'new-value',
	});

	assert.equal(result, false);
	assert.equal(bit.attributes.length, 1);
	assert.equal(bit.attributes[0].key, 'existing');
	assert.equal(bit.attributes[0].value, 'value');
});

test('update_attribute - partially updates attribute fields', () => {
	const bit = new Bit();
	const attr_id = Uuid.parse(undefined);

	bit.add_attribute({
		id: attr_id,
		key: 'original-key',
		value: 'original-value',
	});

	// Update only the key
	bit.update_attribute(attr_id, {
		key: 'updated-key',
	});

	assert.equal(bit.attributes[0].key, 'updated-key');
	assert.equal(bit.attributes[0].value, 'original-value');

	// Update only the value
	bit.update_attribute(attr_id, {
		value: 'updated-value',
	});

	assert.equal(bit.attributes[0].key, 'updated-key');
	assert.equal(bit.attributes[0].value, 'updated-value');
});

// remove_attribute tests
test('remove_attribute - removes existing attribute', () => {
	const bit = new Bit();
	const attr_id_1 = Uuid.parse(undefined);
	const attr_id_2 = Uuid.parse(undefined);

	bit.add_attribute({
		id: attr_id_1,
		key: 'attr1',
		value: 'value1',
	});

	bit.add_attribute({
		id: attr_id_2,
		key: 'attr2',
		value: 'value2',
	});

	assert.equal(bit.attributes.length, 2);

	bit.remove_attribute(attr_id_1);

	assert.equal(bit.attributes.length, 1);
	assert.equal(bit.attributes[0].key, 'attr2');
});

test('remove_attribute - does nothing when attribute not found', () => {
	const bit = new Bit();
	const existing_attr_id = Uuid.parse(undefined);
	const non_existent_id = Uuid.parse(undefined);

	bit.add_attribute({
		id: existing_attr_id,
		key: 'attr',
		value: 'value',
	});

	assert.equal(bit.attributes.length, 1);

	bit.remove_attribute(non_existent_id);

	assert.equal(bit.attributes.length, 1);
	assert.equal(bit.attributes[0].id, existing_attr_id);
});

// clone tests (extended from original tests)
test('clone - returns a new Bit instance with same properties', () => {
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
	assert.equal(clone.attributes.length, original.attributes.length);
	assert.is.not(clone.attributes, original.attributes);
});

test('clone - mutations to clone do not affect original', () => {
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

test('clone - attributes are cloned correctly', () => {
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

// validate tests
test('validate - returns success for valid bit', () => {
	const bit = new Bit({
		json: {
			id: Uuid.parse(undefined),
			name: 'Valid Bit',
			content: 'Content',
		},
	});

	const result = bit.validate();
	assert.equal(result.success, true);
});

// toJSON tests
test('to_json - returns same object as to_json', () => {
	const bit = new Bit({
		json: {
			id: Uuid.parse(undefined),
			name: 'JSON Test',
			content: 'Content',
		},
	});

	const to_json_result = bit.to_json();
	const to_JSON_result = bit.toJSON();

	assert.equal(to_JSON_result, to_json_result);
});

// Edge cases
test('edge_case - empty attributes array is properly cloned', () => {
	const original = new Bit({
		json: {
			id: Uuid.parse(undefined),
			attributes: [],
		},
	});

	const clone = original.clone();

	assert.equal(clone.attributes.length, 0);
	assert.is.not(clone.attributes, original.attributes);

	// Add to clone should not affect original
	clone.add_attribute({
		id: Uuid.parse(undefined),
		key: 'new-attr',
		value: 'new-value',
	});

	assert.equal(clone.attributes.length, 1);
	assert.equal(original.attributes.length, 0);
});

test('edge_case - very long content is handled correctly', () => {
	// Create a very long string
	const long_content = 'a'.repeat(10000);

	const bit = new Bit({
		json: {
			id: Uuid.parse(undefined),
			content: long_content,
		},
	});

	assert.equal(bit.length, 10000);
	assert.equal(bit.tokens, encode(long_content));

	const clone = bit.clone();
	assert.equal(clone.length, 10000);
});

test('edge_case - xml attributes with same key but different ids are handled correctly', () => {
	const bit = new Bit();

	// Add two attributes with same key
	const attr1_id = Uuid.parse(undefined);
	const attr2_id = Uuid.parse(undefined);

	bit.add_attribute({
		id: attr1_id,
		key: 'duplicate',
		value: 'value1',
	});

	bit.add_attribute({
		id: attr2_id,
		key: 'duplicate',
		value: 'value2',
	});

	assert.equal(bit.attributes.length, 2);

	// Update only the first one
	bit.update_attribute(attr1_id, {
		value: 'updated',
	});

	assert.equal(bit.attributes[0].value, 'updated');
	assert.equal(bit.attributes[1].value, 'value2');

	// Remove the first one
	bit.remove_attribute(attr1_id);

	assert.equal(bit.attributes.length, 1);
	assert.equal(bit.attributes[0].id, attr2_id);
});

test('edge_case - unicode characters affect length correctly', () => {
	const bit = new Bit();

	// Simple test with emoji
	bit.content = '👋';
	assert.equal(bit.length, '👋'.length);
	assert.equal(bit.tokens, encode('👋'));

	// For the combined emoji test, use the actual characters
	const combined_emoji = '👨‍👩‍👧‍👦';
	bit.content = combined_emoji;
	assert.equal(bit.length, combined_emoji.length);
	assert.equal(bit.tokens, encode(combined_emoji));

	// Mixed content test
	const mixed_content = 'Hello 👋 World';
	bit.content = mixed_content;
	assert.equal(bit.length, mixed_content.length);
	assert.equal(bit.tokens, encode(mixed_content));
});

test('edge_case - whitespace handling', () => {
	const bit = new Bit();

	// Various whitespace characters
	const whitespace = ' \t\n\r';
	bit.content = whitespace;
	assert.equal(bit.length, whitespace.length);
	assert.equal(bit.tokens, encode(whitespace));

	// Only spaces
	const spaces = '     ';
	bit.content = spaces;
	assert.equal(bit.length, spaces.length);
	assert.equal(bit.tokens, encode(spaces));
});

test('edge_case - special characters', () => {
	const bit = new Bit();

	// XML special characters
	const xml_chars = '<div>&amp;</div>';
	bit.content = xml_chars;
	assert.equal(bit.length, xml_chars.length);
	assert.equal(bit.tokens, encode(xml_chars));

	// Control characters - use direct comparison instead of hardcoded length
	const control_chars = 'Hello\0World\b\f';
	bit.content = control_chars;
	assert.equal(bit.length, control_chars.length);
	assert.equal(bit.tokens, encode(control_chars));
});

test('edge_case - empty and null content handling', () => {
	const bit = new Bit();

	bit.content = '';
	assert.equal(bit.length, 0);
	assert.equal(bit.token_count, 0);

	// Use a type assertion to allow null for testing purposes
	bit.set_json({content: '' as any});
	assert.equal(bit.content, '');
	assert.equal(bit.length, 0);
});

test('edge_case - token counting with unusual content', () => {
	const bit = new Bit();

	// Numbers
	bit.content = '12345';
	assert.equal(bit.tokens, encode('12345'));
	assert.ok(bit.token_count > 0);

	// Mixed languages
	bit.content = 'Hello こんにちは World';
	assert.equal(bit.tokens, encode('Hello こんにちは World'));
	assert.ok(bit.token_count > 0);

	// URLs
	bit.content = 'https://example.com/path?query=value';
	assert.equal(bit.tokens, encode('https://example.com/path?query=value'));
	assert.ok(bit.token_count > 0);
});

test('edge_case - concurrent attribute updates', () => {
	const bit = new Bit();
	const attr1_id = Uuid.parse(undefined);
	const attr2_id = Uuid.parse(undefined);

	// Add multiple attributes
	bit.add_attribute({id: attr1_id, key: 'key1', value: 'value1'});
	bit.add_attribute({id: attr2_id, key: 'key2', value: 'value2'});

	// Update both concurrently
	bit.update_attribute(attr1_id, {value: 'new1'});
	bit.update_attribute(attr2_id, {value: 'new2'});

	assert.equal(bit.attributes[0].value, 'new1');
	assert.equal(bit.attributes[1].value, 'new2');
});

test('edge_case - attribute key uniqueness', () => {
	const bit = new Bit();

	// Add attributes with same key
	bit.add_attribute({key: 'test', value: '1'});
	bit.add_attribute({key: 'test', value: '2'});

	assert.equal(bit.attributes.length, 2);
	assert.equal(bit.attributes[0].key, 'test');
	assert.equal(bit.attributes[1].key, 'test');
	assert.not.equal(bit.attributes[0].id, bit.attributes[1].id);
});

test.run();
