// @vitest-environment jsdom

import {test, expect, describe, beforeEach} from 'vitest';

import {estimate_token_count} from '$lib/helpers.js';
import {create_uuid, get_datetime_now} from '$lib/zod_helpers.js';
import {Zzz} from '$lib/zzz.svelte.js';
import {monkeypatch_zzz_for_tests} from '$lib/test_helpers.js';

// Test suite variables
let zzz: Zzz;

// Test data constants for reuse
const TEST_CONTENT = {
	EMPTY: '',
	INITIAL: 'Initial content',
	NEW_CONTENT: 'New and longer content',
	SOMETHING: 'Something else entirely',
	LONG: 'a'.repeat(10000),
	UNICODE: '😀🌍🏠👨‍👩‍👧‍👦',
	SPECIAL_CHARS: 'Tab:\t Newline:\n Quote:" Backslash:\\',
	CODE: `
function test() {
	return "Hello World";
}

<div class="test">This is <strong>HTML</strong> content</div>
`.trim(),
};

// Setup function to create a real Zzz instance
beforeEach(() => {
	// Create a real Zzz instance
	zzz = monkeypatch_zzz_for_tests(new Zzz());
});

describe('Text_Bit initialization', () => {
	test('creates with default values when no options provided', () => {
		const bit = zzz.registry.instantiate('Text_Bit');

		expect(bit.type).toBe('text');
		expect(bit.content).toBe(TEST_CONTENT.EMPTY);
		expect(bit.length).toBe(TEST_CONTENT.EMPTY.length);
		expect(bit.token_count).toBe(0);
		expect(bit.name).toBe('');
		expect(bit.enabled).toBe(true);
		expect(bit.has_xml_tag).toBe(false);
		expect(bit.xml_tag_name).toBe('');
		expect(bit.attributes).toEqual([]);
		expect(bit.start).toBeNull();
		expect(bit.end).toBeNull();
	});

	test('initializes with direct content property', () => {
		const content = TEST_CONTENT.INITIAL;
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content,
		});

		expect(bit.content).toBe(content);
		expect(bit.length).toBe(content.length);
		expect(bit.token_count).toBe(estimate_token_count(content));
	});

	test('initializes from json with complete properties', () => {
		const test_id = create_uuid();
		const test_date = get_datetime_now();

		const bit = zzz.registry.instantiate('Text_Bit', {
			id: test_id,
			created: test_date,
			type: 'text',
			content: 'Json content',
			name: 'Test name',
			has_xml_tag: true,
			xml_tag_name: 'test-element',
			title: 'Test Title',
			summary: 'Test summary text',
			start: 5,
			end: 20,
			enabled: false,
			attributes: [{id: create_uuid(), key: 'attr1', value: 'value1'}],
		});

		expect(bit.id).toBe(test_id);
		expect(bit.created).toBe(test_date);
		expect(bit.content).toBe('Json content');
		expect(bit.name).toBe('Test name');
		expect(bit.has_xml_tag).toBe(true);
		expect(bit.xml_tag_name).toBe('test-element');
		expect(bit.title).toBe('Test Title');
		expect(bit.summary).toBe('Test summary text');
		expect(bit.start).toBe(5);
		expect(bit.end).toBe(20);
		expect(bit.enabled).toBe(false);
		expect(bit.attributes).toHaveLength(1);
		expect(bit.attributes[0].key).toBe('attr1');
		expect(bit.attributes[0].value).toBe('value1');
	});
});

describe('Text_Bit reactive properties', () => {
	test('derived properties update when content changes', () => {
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: TEST_CONTENT.INITIAL,
		});

		// Verify initial state
		expect(bit.content).toBe(TEST_CONTENT.INITIAL);
		expect(bit.length).toBe(TEST_CONTENT.INITIAL.length);
		const initial_token_count = bit.token_count;

		// Change content
		bit.content = TEST_CONTENT.NEW_CONTENT;

		// Verify derived properties update automatically
		expect(bit.content).toBe(TEST_CONTENT.NEW_CONTENT);
		expect(bit.length).toBe(TEST_CONTENT.NEW_CONTENT.length);
		expect(bit.token_count).not.toBe(initial_token_count);
		expect(bit.token_count).toEqual(estimate_token_count(TEST_CONTENT.NEW_CONTENT));
	});

	test('length is zero when content is empty', () => {
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: TEST_CONTENT.EMPTY,
		});

		expect(bit.content).toBe(TEST_CONTENT.EMPTY);
		expect(bit.length).toBe(TEST_CONTENT.EMPTY.length);

		bit.content = TEST_CONTENT.SOMETHING;
		expect(bit.length).toBe(TEST_CONTENT.SOMETHING.length);

		bit.content = TEST_CONTENT.EMPTY;
		expect(bit.length).toBe(TEST_CONTENT.EMPTY.length);
	});
});

describe('Text_Bit serialization', () => {
	test('to_json includes all properties with correct values', () => {
		const test_id = create_uuid();
		const created = get_datetime_now();

		const bit = zzz.registry.instantiate('Text_Bit', {
			id: test_id,
			created,
			type: 'text',
			content: 'Test content',
			name: 'Test bit',
			start: 10,
			end: 20,
		});

		const json = bit.to_json();

		expect(json.id).toBe(test_id);
		expect(json.type).toBe('text');
		expect(json.created).toBe(created);
		expect(json.content).toBe('Test content');
		expect(json.name).toBe('Test bit');
		expect(json.start).toBe(10);
		expect(json.end).toBe(20);
		expect(json.has_xml_tag).toBe(false);
		expect(json.enabled).toBe(true);
	});

	test('clone creates independent copy with same values', () => {
		const ORIGINAL = {
			CONTENT: 'Original content',
			NAME: 'Original name',
		};
		const MODIFIED = {
			CONTENT: 'Modified content',
			NAME: 'Modified name',
		};

		const original = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: ORIGINAL.CONTENT,
			name: ORIGINAL.NAME,
		});

		const clone = original.clone();

		// Verify they have same initial values except id
		expect(clone.id).not.toBe(original.id);
		expect(clone.content).toBe(ORIGINAL.CONTENT);
		expect(clone.name).toBe(ORIGINAL.NAME);

		// Verify they're independent objects
		clone.content = MODIFIED.CONTENT;
		clone.name = MODIFIED.NAME;

		expect(original.content).toBe(ORIGINAL.CONTENT);
		expect(original.name).toBe(ORIGINAL.NAME);
		expect(clone.content).toBe(MODIFIED.CONTENT);
		expect(clone.name).toBe(MODIFIED.NAME);
	});
});

describe('Text_Bit content modification', () => {
	test('update_content method directly updates content', () => {
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: TEST_CONTENT.INITIAL,
		});

		// Initial state
		expect(bit.content).toBe(TEST_CONTENT.INITIAL);

		// Update content using assignment
		bit.content = TEST_CONTENT.NEW_CONTENT;

		// Verify content was updated
		expect(bit.content).toBe(TEST_CONTENT.NEW_CONTENT);
	});

	test('content setter directly updates content', () => {
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: TEST_CONTENT.INITIAL,
		});

		// Initial state
		expect(bit.content).toBe(TEST_CONTENT.INITIAL);

		// Update content using setter
		bit.content = TEST_CONTENT.NEW_CONTENT;

		// Verify content was updated
		expect(bit.content).toBe(TEST_CONTENT.NEW_CONTENT);
	});
});

describe('Text_Bit content edge cases', () => {
	test('handles long content correctly', () => {
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: TEST_CONTENT.LONG,
		});

		expect(bit.content).toBe(TEST_CONTENT.LONG);
		expect(bit.length).toBe(TEST_CONTENT.LONG.length);
		expect(bit.token_count).toBeGreaterThan(0);
	});

	test('handles unicode characters correctly', () => {
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: TEST_CONTENT.UNICODE,
		});

		expect(bit.content).toBe(TEST_CONTENT.UNICODE);
		expect(bit.length).toBe(TEST_CONTENT.UNICODE.length);
		expect(bit.token_count).toEqual(estimate_token_count(TEST_CONTENT.UNICODE));
	});

	test('handles special characters correctly', () => {
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: TEST_CONTENT.SPECIAL_CHARS,
		});

		expect(bit.content).toBe(TEST_CONTENT.SPECIAL_CHARS);
		expect(bit.length).toBe(TEST_CONTENT.SPECIAL_CHARS.length);
		expect(bit.token_count).toEqual(estimate_token_count(TEST_CONTENT.SPECIAL_CHARS));
	});

	test('handles code and markup content correctly', () => {
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: TEST_CONTENT.CODE,
		});

		expect(bit.content).toBe(TEST_CONTENT.CODE);
		expect(bit.length).toBe(TEST_CONTENT.CODE.length);
		expect(bit.token_count).toEqual(estimate_token_count(TEST_CONTENT.CODE));
	});
});

describe('Text_Bit attribute management', () => {
	test('can add, update and remove attributes', () => {
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: 'Test content',
		});

		// Add attribute
		bit.add_attribute({key: 'class', value: 'highlight'});
		expect(bit.attributes).toHaveLength(1);
		expect(bit.attributes[0].key).toBe('class');
		expect(bit.attributes[0].value).toBe('highlight');

		const attr_id = bit.attributes[0].id;

		// Update attribute
		const updated = bit.update_attribute(attr_id, {value: 'special-highlight'});
		expect(updated).toBe(true);
		expect(bit.attributes[0].key).toBe('class');
		expect(bit.attributes[0].value).toBe('special-highlight');

		// Remove attribute
		bit.remove_attribute(attr_id);
		expect(bit.attributes).toHaveLength(0);

		// Attempting to update non-existent attribute returns false
		const fake_update = bit.update_attribute(create_uuid(), {key: 'test', value: 'test'});
		expect(fake_update).toBe(false);
	});

	test('updates attribute key and value together', () => {
		const bit = zzz.registry.instantiate('Text_Bit');

		bit.add_attribute({key: 'class', value: 'highlight'});
		const attr_id = bit.attributes[0].id;

		// Update both key and value
		const updated = bit.update_attribute(attr_id, {key: 'data-type', value: 'important'});
		expect(updated).toBe(true);
		expect(bit.attributes[0].key).toBe('data-type');
		expect(bit.attributes[0].value).toBe('important');
	});

	test('attributes are preserved when serializing to JSON', () => {
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: 'Test content',
		});

		bit.add_attribute({key: 'data-test', value: 'true'});
		bit.add_attribute({key: 'class', value: 'important'});

		const json = bit.to_json();

		expect(json.attributes).toHaveLength(2);
		expect(json.attributes[0].key).toBe('data-test');
		expect(json.attributes[1].key).toBe('class');

		// Verify they're properly restored
		const new_bit = zzz.registry.instantiate('Text_Bit', json);

		expect(new_bit.attributes).toHaveLength(2);
		expect(new_bit.attributes[0].key).toBe('data-test');
		expect(new_bit.attributes[1].key).toBe('class');
	});
});

describe('Text_Bit instance management', () => {
	test('bit is added to registry when created', () => {
		// Create a bit
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: 'Registry test content',
		});

		// Add to the registry
		zzz.bits.items.add(bit);

		// Verify it's in the registry
		const retrieved_bit = zzz.bits.items.by_id.get(bit.id);
		expect(retrieved_bit).toBe(bit);
	});

	test('bit is removed from registry when requested', () => {
		// Create a bit and add to registry
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: 'Removable content',
		});

		zzz.bits.items.add(bit);

		// Verify it's in the registry
		expect(zzz.bits.items.by_id.get(bit.id)).toBe(bit);

		// Remove from registry
		zzz.bits.items.remove(bit.id);

		// Verify it's gone
		expect(zzz.bits.items.by_id.get(bit.id)).toBeUndefined();
	});
});

describe('Text_Bit start and end position markers', () => {
	test('start and end positions are initialized properly', () => {
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: 'Position test',
			start: 10,
			end: 25,
		});

		expect(bit.start).toBe(10);
		expect(bit.end).toBe(25);
	});

	test('start and end positions can be updated', () => {
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: 'Position test',
		});

		// Initial values are null
		expect(bit.start).toBeNull();
		expect(bit.end).toBeNull();

		// Update positions
		bit.start = 5;
		bit.end = 15;

		expect(bit.start).toBe(5);
		expect(bit.end).toBe(15);
	});

	test('positions are preserved when serializing and deserializing', () => {
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: 'Position preservation test',
			start: 8,
			end: 30,
		});

		// Serialize to JSON
		const json = bit.to_json();

		// Create new bit from JSON
		const new_bit = zzz.registry.instantiate('Text_Bit', json);

		// Verify positions were preserved
		expect(new_bit.start).toBe(8);
		expect(new_bit.end).toBe(30);
	});
});
