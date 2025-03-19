// @vitest-environment jsdom

import {test, expect, describe} from 'vitest';
import {encode as tokenize} from 'gpt-tokenizer';

import {Text_Bit} from '$lib/bit.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';

// A mock Zzz instance with minimal required functionality
const create_mock_zzz = (): any => ({
	cells: new Map(),
	bits: {
		items: {
			by_id: new Map(),
		},
	},
	diskfiles: {
		get_by_path: () => undefined,
	},
});

// Test data constants for reuse
const TEST_CONTENT = {
	EMPTY: '',
	INITIAL: 'Initial',
	NEW_CONTENT: 'New longer content',
	SOMETHING: 'Something',
};

describe('Text_Bit initialization', () => {
	test('creates with default values when no options provided', () => {
		const mock_zzz = create_mock_zzz();
		const bit = new Text_Bit({zzz: mock_zzz});

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
		const mock_zzz = create_mock_zzz();
		const content = 'Test content';
		const bit = new Text_Bit({
			zzz: mock_zzz,
			json: {content},
		});

		expect(bit.content).toBe(content);
		expect(bit.length).toBe(content.length);
		expect(bit.tokens).toEqual(tokenize(content));
		expect(bit.token_count).toBe(tokenize(content).length);
	});

	test('initializes from json with complete properties', () => {
		const mock_zzz = create_mock_zzz();
		const test_id = Uuid.parse(undefined);
		const test_date = new Date().toISOString();

		const bit = new Text_Bit({
			zzz: mock_zzz,
			json: {
				id: test_id,
				type: 'text',
				created: test_date,
				content: 'Json content',
				name: 'Test name',
				has_xml_tag: true,
				xml_tag_name: 'test-element',
				title: 'Test Title',
				summary: 'Test summary text',
				start: 5,
				end: 20,
				enabled: false,
				attributes: [{id: Uuid.parse(undefined), key: 'attr1', value: 'value1'}],
			},
		});

		expect(bit.id).toBe(test_id);
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
	});
});

describe('Text_Bit reactive properties', () => {
	test('derived properties update when content changes', () => {
		const mock_zzz = create_mock_zzz();
		const bit = new Text_Bit({
			zzz: mock_zzz,
			json: {type: 'text', content: TEST_CONTENT.INITIAL},
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
		expect(bit.tokens).toEqual(tokenize(TEST_CONTENT.NEW_CONTENT));
	});

	test('length is zero when content is empty', () => {
		const mock_zzz = create_mock_zzz();
		const bit = new Text_Bit({
			zzz: mock_zzz,
			json: {type: 'text'}, // Must provide the type for Zod validation
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
		const mock_zzz = create_mock_zzz();
		const test_id = Uuid.parse(undefined);
		const created = new Date().toISOString();

		const bit = new Text_Bit({
			zzz: mock_zzz,
			json: {
				id: test_id,
				created,
				type: 'text',
				content: 'Test content',
				name: 'Test bit',
				start: 10,
				end: 20,
			},
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
		const mock_zzz = create_mock_zzz();
		const ORIGINAL = {
			CONTENT: 'Original content',
			NAME: 'Original name',
		};
		const MODIFIED = {
			CONTENT: 'Modified content',
			NAME: 'Modified name',
		};

		const original = new Text_Bit({
			zzz: mock_zzz,
			json: {
				type: 'text',
				content: ORIGINAL.CONTENT,
				name: ORIGINAL.NAME,
			},
		});

		const clone = original.clone();

		// Verify they have same initial values
		expect(clone.id).toBe(original.id);
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

describe('Text_Bit content edge cases', () => {
	test('handles long content correctly', () => {
		const mock_zzz = create_mock_zzz();
		const REPEAT_COUNT = 10000;
		const long_content = 'a'.repeat(REPEAT_COUNT);
		const bit = new Text_Bit({
			zzz: mock_zzz,
			json: {
				type: 'text',
				content: long_content,
			},
		});

		expect(bit.content).toBe(long_content);
		expect(bit.length).toBe(REPEAT_COUNT);
		expect(bit.token_count).toBeGreaterThan(0);
	});

	test('handles unicode characters correctly', () => {
		const mock_zzz = create_mock_zzz();
		const emoji_content = '😀🌍🏠👨‍👩‍👧‍👦';
		const bit = new Text_Bit({
			zzz: mock_zzz,
			json: {
				type: 'text',
				content: emoji_content,
			},
		});

		expect(bit.content).toBe(emoji_content);
		expect(bit.length).toBe(emoji_content.length);
		expect(bit.tokens).toEqual(tokenize(emoji_content));
	});

	test('handles special characters correctly', () => {
		const mock_zzz = create_mock_zzz();
		const special_chars = 'Tab:\t Newline:\n Quote:" Backslash:\\';
		const bit = new Text_Bit({
			zzz: mock_zzz,
			json: {
				type: 'text',
				content: special_chars,
			},
		});

		expect(bit.content).toBe(special_chars);
		expect(bit.length).toBe(special_chars.length);
		expect(bit.tokens).toEqual(tokenize(special_chars));
	});

	test('handles code and markup content correctly', () => {
		const mock_zzz = create_mock_zzz();
		const code_content = `
function test() {
	return "Hello World";
}

<div class="test">This is <strong>HTML</strong> content</div>
		`.trim();

		const bit = new Text_Bit({
			zzz: mock_zzz,
			json: {
				type: 'text',
				content: code_content,
			},
		});

		expect(bit.content).toBe(code_content);
		expect(bit.length).toBe(code_content.length);
		expect(bit.tokens).toEqual(tokenize(code_content));
	});
});

describe('Text_Bit attribute management', () => {
	test('can add, update and remove attributes', () => {
		const mock_zzz = create_mock_zzz();
		const bit = new Text_Bit({
			zzz: mock_zzz,
			json: {
				type: 'text',
				content: 'Test content',
			},
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
		const fake_update = bit.update_attribute(Uuid.parse(undefined), {key: 'test', value: 'test'});
		expect(fake_update).toBe(false);
	});

	test('attributes are preserved when serializing to JSON', () => {
		const mock_zzz = create_mock_zzz();
		const bit = new Text_Bit({
			zzz: mock_zzz,
			json: {
				type: 'text',
				content: 'Test content',
			},
		});

		bit.add_attribute({key: 'data-test', value: 'true'});
		bit.add_attribute({key: 'class', value: 'important'});

		const json = bit.to_json();

		expect(json.attributes).toHaveLength(2);
		expect(json.attributes[0].key).toBe('data-test');
		expect(json.attributes[1].key).toBe('class');

		// Verify they're properly restored
		const new_bit = new Text_Bit({
			zzz: mock_zzz,
			json,
		});

		expect(new_bit.attributes).toHaveLength(2);
		expect(new_bit.attributes[0].key).toBe('data-test');
		expect(new_bit.attributes[1].key).toBe('class');
	});
});
