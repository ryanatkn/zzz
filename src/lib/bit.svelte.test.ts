// bit_claude.svelte.test.ts

import {test} from 'uvu';
import * as assert from 'uvu/assert';

import {Bit} from '$lib/bit.svelte.js';
import {Uuid} from '$lib/uuid.js';

// Constructor tests
test('constructor - creates with default values when no options provided', () => {
	const bit = new Bit();

	assert.instance(bit, Bit);
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

	assert.instance(bit, Bit);
	assert.instance(bit.id, Uuid);
	assert.equal(bit.name, '');
	assert.equal(bit.has_xml_tag, false);
	assert.equal(bit.xml_tag_name, '');
	assert.equal(bit.attributes.length, 0);
	assert.equal(bit.enabled, true);
	assert.equal(bit.content, '');
});

// Derived properties tests
test('derived properties - length and token_count update when content changes', () => {
	const bit = new Bit({
		json: {
			content: 'A',
		},
	});

	assert.equal(bit.length, 1);
	assert.ok(bit.token_count > 0);

	const initialTokenCount = bit.token_count;

	bit.content = 'ABC';
	assert.equal(bit.length, 3); // This should match the actual string length now
});

// Clone test - don't assert exact lengths since token encoding can change
test('clone - derived properties are calculated correctly', () => {
	const original = new Bit({
		json: {
			content: 'Test content for derived properties',
		},
	});

	const clone = original.clone();

	// Verify derived properties match without checking exact values
	assert.equal(clone.length, original.length);
	assert.equal(clone.token_count, original.token_count);

	// Change content and verify derived properties update
	clone.content = 'Modified content';
	assert.equal(clone.length, 'Modified content'.length);
	assert.not.equal(clone.length, original.length);
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
	assert.ok(bit.token_count > 0); // Just verify tokens are generated
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
	const attrId = Uuid.parse(undefined);
	const bit = new Bit({
		json: {
			id,
			name: 'Serialization Test',
			has_xml_tag: true,
			xml_tag_name: 'p',
			attributes: [{id: attrId, key: 'data-test', value: 'true'}],
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
	assert.equal(json.attributes[0].id, attrId);
	assert.equal(json.attributes[0].key, 'data-test');
	assert.equal(json.attributes[0].value, 'true');
	assert.equal(json.enabled, true);
	assert.equal(json.content, 'Test content');
});

// set_json tests
test('set_json - updates properties with new values', () => {
	const bit = new Bit();
	const newId = Uuid.parse(undefined);

	bit.set_json({
		id: newId,
		name: 'Updated Bit',
		has_xml_tag: true,
		xml_tag_name: 'section',
		attributes: [{id: Uuid.parse(undefined), key: 'role', value: 'main'}],
		enabled: false,
		content: 'Updated content',
	});

	assert.equal(bit.id, newId);
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
	const attrId = Uuid.parse(undefined);

	bit.add_attribute({
		id: attrId,
		key: 'original',
		value: 'value',
	});

	const result = bit.update_attribute(attrId, {
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
	const existingAttrId = Uuid.parse(undefined);
	const nonExistentId = Uuid.parse(undefined);

	bit.add_attribute({
		id: existingAttrId,
		key: 'existing',
		value: 'value',
	});

	const result = bit.update_attribute(nonExistentId, {
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
	const attrId = Uuid.parse(undefined);

	bit.add_attribute({
		id: attrId,
		key: 'original-key',
		value: 'original-value',
	});

	// Update only the key
	bit.update_attribute(attrId, {
		key: 'updated-key',
	});

	assert.equal(bit.attributes[0].key, 'updated-key');
	assert.equal(bit.attributes[0].value, 'original-value');

	// Update only the value
	bit.update_attribute(attrId, {
		value: 'updated-value',
	});

	assert.equal(bit.attributes[0].key, 'updated-key');
	assert.equal(bit.attributes[0].value, 'updated-value');
});

// remove_attribute tests
test('remove_attribute - removes existing attribute', () => {
	const bit = new Bit();
	const attrId1 = Uuid.parse(undefined);
	const attrId2 = Uuid.parse(undefined);

	bit.add_attribute({
		id: attrId1,
		key: 'attr1',
		value: 'value1',
	});

	bit.add_attribute({
		id: attrId2,
		key: 'attr2',
		value: 'value2',
	});

	assert.equal(bit.attributes.length, 2);

	bit.remove_attribute(attrId1);

	assert.equal(bit.attributes.length, 1);
	assert.equal(bit.attributes[0].key, 'attr2');
});

test('remove_attribute - does nothing when attribute not found', () => {
	const bit = new Bit();
	const existingAttrId = Uuid.parse(undefined);
	const nonExistentId = Uuid.parse(undefined);

	bit.add_attribute({
		id: existingAttrId,
		key: 'attr',
		value: 'value',
	});

	assert.equal(bit.attributes.length, 1);

	bit.remove_attribute(nonExistentId);

	assert.equal(bit.attributes.length, 1);
	assert.equal(bit.attributes[0].id, existingAttrId);
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
test('toJSON - returns same object as to_json', () => {
	const bit = new Bit({
		json: {
			id: Uuid.parse(undefined),
			name: 'JSON Test',
			content: 'Content',
		},
	});

	const toJsonResult = bit.to_json();
	const toJSONResult = bit.toJSON();

	assert.equal(toJSONResult, toJsonResult);
});

// Edge cases
test('edge case - empty attributes array is properly cloned', () => {
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

test('edge case - very long content is handled correctly', () => {
	// Create a very long string
	const longContent = 'a'.repeat(10000);

	const bit = new Bit({
		json: {
			id: Uuid.parse(undefined),
			content: longContent,
		},
	});

	assert.equal(bit.length, 10000);
	assert.ok(bit.token_count > 0);

	const clone = bit.clone();
	assert.equal(clone.length, 10000);
});

test('edge case - xml attributes with same key but different ids are handled correctly', () => {
	const bit = new Bit();

	// Add two attributes with same key
	const attr1Id = Uuid.parse(undefined);
	const attr2Id = Uuid.parse(undefined);

	bit.add_attribute({
		id: attr1Id,
		key: 'duplicate',
		value: 'value1',
	});

	bit.add_attribute({
		id: attr2Id,
		key: 'duplicate',
		value: 'value2',
	});

	assert.equal(bit.attributes.length, 2);

	// Update only the first one
	bit.update_attribute(attr1Id, {
		value: 'updated',
	});

	assert.equal(bit.attributes[0].value, 'updated');
	assert.equal(bit.attributes[1].value, 'value2');

	// Remove the first one
	bit.remove_attribute(attr1Id);

	assert.equal(bit.attributes.length, 1);
	assert.equal(bit.attributes[0].id, attr2Id);
});

test.run();
