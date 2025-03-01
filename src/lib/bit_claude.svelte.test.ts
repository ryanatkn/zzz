import {test} from 'uvu';
import * as assert from 'uvu/assert';

import {Bit} from '$lib/bit.svelte.js';
import {Uuid} from '$lib/uuid.js';

test('constructor - creates with default values when no options provided', () => {
	const bit = new Bit();

	assert.ok(bit instanceof Bit, 'Should be an instance of Bit');
	assert.ok(bit.id, 'Bit should have a generated id');
	assert.is(bit.name, '', 'Default name is empty string');
	assert.is(bit.has_xml_tag, false, 'Default has_xml_tag is false');
	assert.is(bit.xml_tag_name, '', 'Default xml_tag_name is empty string');
	assert.ok(Array.isArray(bit.attributes), 'attributes is an array by default');
	assert.is(bit.attributes.length, 0, 'Default attributes array is empty');
	assert.is(bit.enabled, true, 'Default enabled is true');
	assert.is(bit.content, '', 'Default content is empty string');
	assert.is(bit.length, 0, 'Length is 0 for empty content');
	assert.ok(Array.isArray(bit.tokens), 'Tokens should be an array');
	assert.is(bit.token_count, 0, 'Token count is 0 for empty content');
});

test('constructor - creates with provided values', () => {
	const id = Uuid.parse(undefined);
	const bit = new Bit({
		json: {
			id,
			name: 'Test Bit',
			content: 'Sample content',
			has_xml_tag: true,
			xml_tag_name: 'sample',
			attributes: [{id: Uuid.parse(undefined), key: 'test', value: 'value'}],
			enabled: false,
		},
	});

	assert.is(bit.id, id);
	assert.is(bit.name, 'Test Bit');
	assert.is(bit.content, 'Sample content');
	assert.is(bit.has_xml_tag, true);
	assert.is(bit.xml_tag_name, 'sample');
	assert.is(bit.attributes.length, 1);
	assert.is(bit.attributes[0].key, 'test');
	assert.is(bit.enabled, false);
	assert.is(bit.length, 'Sample content'.length);
});

test('from_json - creates a Bit with default values when no json provided', () => {
	const bit = Bit.from_json();

	assert.ok(bit instanceof Bit, 'Should be an instance of Bit');
	assert.is(bit.name, '', 'Default name is empty string');
	assert.is(bit.content, '', 'Default content is empty string');
});

test('from_json - creates a Bit with provided values', () => {
	const id = Uuid.parse(undefined);
	const bit = Bit.from_json({
		id,
		name: 'Test Bit',
		content: 'Sample content',
	});

	assert.is(bit.id, id);
	assert.is(bit.name, 'Test Bit');
	assert.is(bit.content, 'Sample content');
});

test('derived properties - length and token_count update when content changes', () => {
	const bit = new Bit();

	// Initially empty
	assert.is(bit.length, 0);
	assert.is(bit.token_count, 0);

	// Update content
	bit.content = 'abc';
	assert.is(bit.length, 3);
	assert.ok(bit.token_count > 0, 'Token count should be greater than 0');
});

test('attribute management - add, update, remove', () => {
	const bit = new Bit();

	// Add attribute
	bit.add_attribute({key: 'key1', value: 'value1'});
	assert.is(bit.attributes.length, 1);
	assert.is(bit.attributes[0].key, 'key1');

	// Update attribute
	const id = bit.attributes[0].id;
	const updated = bit.update_attribute(id, {value: 'updated'});
	assert.is(updated, true);
	assert.is(bit.attributes[0].value, 'updated');

	// Update non-existent attribute
	const nonExistentId = Uuid.parse(undefined);
	const notUpdated = bit.update_attribute(nonExistentId, {value: 'fail'});
	assert.is(notUpdated, false);

	// Remove attribute
	bit.remove_attribute(id);
	assert.is(bit.attributes.length, 0);
});

test('clone - creates independent copy', () => {
	const original = new Bit({
		json: {
			name: 'Original',
			content: 'Original content',
		},
	});

	const clone = original.clone();

	// Should be independent instances
	assert.ok(clone instanceof Bit);
	assert.is.not(clone, original);

	// Should have same values
	assert.is(clone.name, 'Original');
	assert.is(clone.content, 'Original content');

	// Modifying clone shouldn't affect original
	clone.name = 'Modified';
	clone.content = 'Modified content';
	assert.is(original.name, 'Original');
	assert.is(original.content, 'Original content');
	assert.is(clone.name, 'Modified');
	assert.is(clone.content, 'Modified content');
});

test('clone - derived properties are calculated correctly', () => {
	const original = new Bit({
		json: {
			content: 'This is a test content',
		},
	});

	const clone = original.clone();
	assert.is(clone.length, 'This is a test content'.length);
	assert.is(clone.length, 21); // Explicit length check
});

test.run();
