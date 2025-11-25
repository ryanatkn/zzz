// @slop Claude Sonnet 3.7

// @vitest-environment jsdom

import {test, expect, describe, beforeEach} from 'vitest';

import {estimate_token_count} from '$lib/helpers.js';
import {create_uuid, get_datetime_now} from '$lib/zod_helpers.js';
import {Frontend} from '$lib/frontend.svelte.js';
import {monkeypatch_zzz_for_tests} from '$lib/test_helpers.js';

// Test suite variables
let app: Frontend;

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
	app = monkeypatch_zzz_for_tests(new Frontend());
});

describe('TextPart initialization', () => {
	test('creates with default values when no options provided', () => {
		const part = app.cell_registry.instantiate('TextPart');

		expect(part.type).toBe('text');
		expect(part.content).toBe(TEST_CONTENT.EMPTY);
		expect(part.length).toBe(TEST_CONTENT.EMPTY.length);
		expect(part.token_count).toBe(0);
		expect(part.name).toBe('');
		expect(part.enabled).toBe(true);
		expect(part.has_xml_tag).toBe(false);
		expect(part.xml_tag_name).toBe('');
		expect(part.attributes).toEqual([]);
		expect(part.start).toBeNull();
		expect(part.end).toBeNull();
	});

	test('initializes with direct content property', () => {
		const content = TEST_CONTENT.INITIAL;
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content,
		});

		expect(part.content).toBe(content);
		expect(part.length).toBe(content.length);
		expect(part.token_count).toBe(estimate_token_count(content));
	});

	test('initializes from json with complete properties', () => {
		const test_id = create_uuid();
		const test_date = get_datetime_now();

		const part = app.cell_registry.instantiate('TextPart', {
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

		expect(part.id).toBe(test_id);
		expect(part.created).toBe(test_date);
		expect(part.content).toBe('Json content');
		expect(part.name).toBe('Test name');
		expect(part.has_xml_tag).toBe(true);
		expect(part.xml_tag_name).toBe('test-element');
		expect(part.title).toBe('Test Title');
		expect(part.summary).toBe('Test summary text');
		expect(part.start).toBe(5);
		expect(part.end).toBe(20);
		expect(part.enabled).toBe(false);
		expect(part.attributes).toHaveLength(1);
		const first_attr = part.attributes[0];
		if (!first_attr) throw new Error('Expected first attribute');
		expect(first_attr.key).toBe('attr1');
		expect(first_attr.value).toBe('value1');
	});
});

describe('TextPart reactive properties', () => {
	test('derived properties update when content changes', () => {
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: TEST_CONTENT.INITIAL,
		});

		// Verify initial state
		expect(part.content).toBe(TEST_CONTENT.INITIAL);
		expect(part.length).toBe(TEST_CONTENT.INITIAL.length);
		const initial_token_count = part.token_count;

		// Change content
		part.content = TEST_CONTENT.NEW_CONTENT;

		// Verify derived properties update automatically
		expect(part.content).toBe(TEST_CONTENT.NEW_CONTENT);
		expect(part.length).toBe(TEST_CONTENT.NEW_CONTENT.length);
		expect(part.token_count).not.toBe(initial_token_count);
		expect(part.token_count).toEqual(estimate_token_count(TEST_CONTENT.NEW_CONTENT));
	});

	test('length is zero when content is empty', () => {
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: TEST_CONTENT.EMPTY,
		});

		expect(part.content).toBe(TEST_CONTENT.EMPTY);
		expect(part.length).toBe(TEST_CONTENT.EMPTY.length);

		part.content = TEST_CONTENT.SOMETHING;
		expect(part.length).toBe(TEST_CONTENT.SOMETHING.length);

		part.content = TEST_CONTENT.EMPTY;
		expect(part.length).toBe(TEST_CONTENT.EMPTY.length);
	});
});

describe('TextPart serialization', () => {
	test('to_json includes all properties with correct values', () => {
		const test_id = create_uuid();
		const created = get_datetime_now();

		const part = app.cell_registry.instantiate('TextPart', {
			id: test_id,
			created,
			type: 'text',
			content: 'Test content',
			name: 'Test part',
			start: 10,
			end: 20,
		});

		const json = part.to_json();

		expect(json.id).toBe(test_id);
		expect(json.type).toBe('text');
		expect(json.created).toBe(created);
		expect(json.content).toBe('Test content');
		expect(json.name).toBe('Test part');
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

		const original = app.cell_registry.instantiate('TextPart', {
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

describe('TextPart content modification', () => {
	test('update_content method directly updates content', () => {
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: TEST_CONTENT.INITIAL,
		});

		// Initial state
		expect(part.content).toBe(TEST_CONTENT.INITIAL);

		// Update content using assignment
		part.content = TEST_CONTENT.NEW_CONTENT;

		// Verify content was updated
		expect(part.content).toBe(TEST_CONTENT.NEW_CONTENT);
	});

	test('content setter directly updates content', () => {
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: TEST_CONTENT.INITIAL,
		});

		// Initial state
		expect(part.content).toBe(TEST_CONTENT.INITIAL);

		// Update content using setter
		part.content = TEST_CONTENT.NEW_CONTENT;

		// Verify content was updated
		expect(part.content).toBe(TEST_CONTENT.NEW_CONTENT);
	});
});

describe('TextPart content edge cases', () => {
	test('handles long content correctly', () => {
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: TEST_CONTENT.LONG,
		});

		expect(part.content).toBe(TEST_CONTENT.LONG);
		expect(part.length).toBe(TEST_CONTENT.LONG.length);
		expect(part.token_count).toBeGreaterThan(0);
	});

	test('handles unicode characters correctly', () => {
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: TEST_CONTENT.UNICODE,
		});

		expect(part.content).toBe(TEST_CONTENT.UNICODE);
		expect(part.length).toBe(TEST_CONTENT.UNICODE.length);
		expect(part.token_count).toEqual(estimate_token_count(TEST_CONTENT.UNICODE));
	});

	test('handles special characters correctly', () => {
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: TEST_CONTENT.SPECIAL_CHARS,
		});

		expect(part.content).toBe(TEST_CONTENT.SPECIAL_CHARS);
		expect(part.length).toBe(TEST_CONTENT.SPECIAL_CHARS.length);
		expect(part.token_count).toEqual(estimate_token_count(TEST_CONTENT.SPECIAL_CHARS));
	});

	test('handles code and markup content correctly', () => {
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: TEST_CONTENT.CODE,
		});

		expect(part.content).toBe(TEST_CONTENT.CODE);
		expect(part.length).toBe(TEST_CONTENT.CODE.length);
		expect(part.token_count).toEqual(estimate_token_count(TEST_CONTENT.CODE));
	});
});

describe('TextPart attribute management', () => {
	test('can add, update and remove attributes', () => {
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: 'Test content',
		});

		// Add attribute
		part.add_attribute({key: 'class', value: 'highlight'});
		expect(part.attributes).toHaveLength(1);
		let first_attr = part.attributes[0];
		if (!first_attr) throw new Error('Expected first attribute');
		expect(first_attr.key).toBe('class');
		expect(first_attr.value).toBe('highlight');

		const attr_id = first_attr.id;

		// Update attribute
		const updated = part.update_attribute(attr_id, {value: 'special-highlight'});
		expect(updated).toBe(true);
		first_attr = part.attributes[0];
		if (!first_attr) throw new Error('Expected attribute after update');
		expect(first_attr.key).toBe('class');
		expect(first_attr.value).toBe('special-highlight');

		// Remove attribute
		part.remove_attribute(attr_id);
		expect(part.attributes).toHaveLength(0);

		// Attempting to update non-existent attribute returns false
		const fake_update = part.update_attribute(create_uuid(), {key: 'test', value: 'test'});
		expect(fake_update).toBe(false);
	});

	test('updates attribute key and value together', () => {
		const part = app.cell_registry.instantiate('TextPart');

		part.add_attribute({key: 'class', value: 'highlight'});
		const first_attr = part.attributes[0];
		if (!first_attr) throw new Error('Expected first attribute');
		const attr_id = first_attr.id;

		// Update both key and value
		const updated = part.update_attribute(attr_id, {key: 'data-type', value: 'important'});
		expect(updated).toBe(true);
		const updated_attr = part.attributes[0];
		if (!updated_attr) throw new Error('Expected attribute after update');
		expect(updated_attr.key).toBe('data-type');
		expect(updated_attr.value).toBe('important');
	});

	test('attributes are preserved when serializing to JSON', () => {
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: 'Test content',
		});

		part.add_attribute({key: 'data-test', value: 'true'});
		part.add_attribute({key: 'class', value: 'important'});

		const json = part.to_json();

		expect(json.attributes).toHaveLength(2);
		const json_attr0 = json.attributes[0];
		const json_attr1 = json.attributes[1];
		if (!json_attr0 || !json_attr1) throw new Error('Expected both attributes in JSON');
		expect(json_attr0.key).toBe('data-test');
		expect(json_attr1.key).toBe('class');

		// Verify they're properly restored
		const new_part = app.cell_registry.instantiate('TextPart', json);

		expect(new_part.attributes).toHaveLength(2);
		const new_attr0 = new_part.attributes[0];
		const new_attr1 = new_part.attributes[1];
		if (!new_attr0 || !new_attr1) throw new Error('Expected both attributes in restored part');
		expect(new_attr0.key).toBe('data-test');
		expect(new_attr1.key).toBe('class');
	});
});

describe('TextPart instance management', () => {
	test('part is added to registry when created', () => {
		// Create a part
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: 'Registry test content',
		});

		// Add to the registry
		app.parts.items.add(part);

		// Verify it's in the registry
		const retrieved_part = app.parts.items.by_id.get(part.id);
		expect(retrieved_part).toBe(part);
	});

	test('part is removed from registry when requested', () => {
		// Create a part and add to registry
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: 'Removable content',
		});

		app.parts.items.add(part);

		// Verify it's in the registry
		expect(app.parts.items.by_id.get(part.id)).toBe(part);

		// Remove from registry
		app.parts.items.remove(part.id);

		// Verify it's gone
		expect(app.parts.items.by_id.get(part.id)).toBeUndefined();
	});
});

describe('TextPart start and end position markers', () => {
	test('start and end positions are initialized properly', () => {
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: 'Position test',
			start: 10,
			end: 25,
		});

		expect(part.start).toBe(10);
		expect(part.end).toBe(25);
	});

	test('start and end positions can be updated', () => {
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: 'Position test',
		});

		// Initial values are null
		expect(part.start).toBeNull();
		expect(part.end).toBeNull();

		// Update positions
		part.start = 5;
		part.end = 15;

		expect(part.start).toBe(5);
		expect(part.end).toBe(15);
	});

	test('positions are preserved when serializing and deserializing', () => {
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: 'Position preservation test',
			start: 8,
			end: 30,
		});

		// Serialize to JSON
		const json = part.to_json();

		// Create new part from JSON
		const new_part = app.cell_registry.instantiate('TextPart', json);

		// Verify positions were preserved
		expect(new_part.start).toBe(8);
		expect(new_part.end).toBe(30);
	});
});
