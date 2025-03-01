// bit.svelte.test.ts

import {test} from 'uvu';
import * as assert from 'uvu/assert';

import {Bit} from '$lib/bit.svelte.js';
import {Uuid} from '$lib/uuid.js';

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
	assert.is(clone.id, original.id);
	assert.is(clone.name, original.name);
	assert.is(clone.content, original.content);
	assert.equal(clone.attributes, original.attributes);
	assert.is.not(clone.attributes, original.attributes);
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
