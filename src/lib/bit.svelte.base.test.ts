// @vitest-environment jsdom

import {test, expect, describe, beforeEach} from 'vitest';
import {encode as tokenize} from 'gpt-tokenizer';

import {Bit, Text_Bit, Diskfile_Bit, Sequence_Bit} from '$lib/bit.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Diskfile_Path} from '$lib/diskfile_types.js';
import {Zzz} from '$lib/zzz.svelte.js';
import {monkeypatch_zzz_for_tests} from '$lib/test_helpers.js';

// Test suite variables
let zzz: Zzz;

// Test constants
const TEST_CONTENT = {
	BASIC: 'Basic test content',
	SECONDARY: 'Secondary test content',
	EMPTY: '',
};

const TEST_PATH = Diskfile_Path.parse('/path/to/test/file.txt');

beforeEach(() => {
	// Create a real Zzz instance for each test
	zzz = monkeypatch_zzz_for_tests(new Zzz());
});

describe('Bit base class functionality', () => {
	test('attribute management works across all bit types', () => {
		// Test with different bit types
		const text_bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: TEST_CONTENT.BASIC,
		});

		const diskfile_bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path: TEST_PATH,
		});

		const sequence_bit = zzz.registry.instantiate('Sequence_Bit', {
			type: 'sequence',
		});

		// Test each bit type
		for (const bit of [text_bit, diskfile_bit, sequence_bit]) {
			// Add attribute
			bit.add_attribute({key: 'test-attr', value: 'test-value'});
			expect(bit.attributes).toHaveLength(1);
			expect(bit.attributes[0].key).toBe('test-attr');
			expect(bit.attributes[0].value).toBe('test-value');

			const attr_id = bit.attributes[0].id;

			// Update attribute value
			const updated = bit.update_attribute(attr_id, {value: 'updated-value'});
			expect(updated).toBe(true);
			expect(bit.attributes[0].key).toBe('test-attr');
			expect(bit.attributes[0].value).toBe('updated-value');

			// Update attribute key and value
			bit.update_attribute(attr_id, {key: 'updated-key', value: 'updated-value-2'});
			expect(bit.attributes[0].key).toBe('updated-key');
			expect(bit.attributes[0].value).toBe('updated-value-2');

			// Remove attribute
			bit.remove_attribute(attr_id);
			expect(bit.attributes).toHaveLength(0);

			// Try to update non-existent attribute
			const non_existent_update = bit.update_attribute(Uuid.parse(undefined), {
				value: 'test',
			});
			expect(non_existent_update).toBe(false);
		}
	});

	test('derived properties work correctly', () => {
		// Create a text bit to test length and token properties
		const text_bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: TEST_CONTENT.BASIC,
		});

		// Test initial derivations
		expect(text_bit.length).toBe(TEST_CONTENT.BASIC.length);
		expect(text_bit.tokens).toEqual(tokenize(TEST_CONTENT.BASIC));
		expect(text_bit.token_count).toBe(tokenize(TEST_CONTENT.BASIC).length);

		// Test derivations after content change
		text_bit.content = TEST_CONTENT.SECONDARY;

		expect(text_bit.length).toBe(TEST_CONTENT.SECONDARY.length);
		expect(text_bit.tokens).toEqual(tokenize(TEST_CONTENT.SECONDARY));
		expect(text_bit.token_count).toBe(tokenize(TEST_CONTENT.SECONDARY).length);
	});
});

describe('Bit factory method', () => {
	test('Bit.create creates the correct bit type based on JSON', () => {
		// Create bits using the static factory
		const text_bit = Bit.create(zzz, {
			type: 'text',
			content: TEST_CONTENT.BASIC,
			name: 'Text Bit',
		});

		const diskfile_bit = Bit.create(zzz, {
			type: 'diskfile',
			path: TEST_PATH,
			name: 'Diskfile Bit',
		});

		const sequence_bit = Bit.create(zzz, {
			type: 'sequence',
			items: [],
			name: 'Sequence Bit',
		});

		// Verify the correct type was created
		expect(text_bit).toBeInstanceOf(Text_Bit);
		expect(text_bit.type).toBe('text');
		expect(text_bit.name).toBe('Text Bit');
		expect(text_bit.content).toBe(TEST_CONTENT.BASIC);

		expect(diskfile_bit).toBeInstanceOf(Diskfile_Bit);
		expect(diskfile_bit.type).toBe('diskfile');
		expect(diskfile_bit.name).toBe('Diskfile Bit');
		expect(diskfile_bit.path).toBe(TEST_PATH);

		expect(sequence_bit).toBeInstanceOf(Sequence_Bit);
		expect(sequence_bit.type).toBe('sequence');
		expect(sequence_bit.name).toBe('Sequence Bit');
		expect(sequence_bit.items).toEqual([]);
	});

	test('Bit.create throws error for unknown bit type', () => {
		const invalid_json = {
			type: 'unknown' as const,
		};

		expect(() => Bit.create(zzz, invalid_json as any)).toThrow('Unreachable case: unknown');
	});

	test('Bit.create throws error for missing type field', () => {
		const invalid_json = {
			name: 'Test',
		};

		expect(() => Bit.create(zzz, invalid_json as any)).toThrow(
			'Missing required "type" field in bit JSON',
		);
	});
});

describe('Text_Bit specific behavior', () => {
	test('Text_Bit initialization and content management', () => {
		// Create with constructor
		const bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: TEST_CONTENT.BASIC,
		});

		expect(bit.type).toBe('text');
		expect(bit.content).toBe(TEST_CONTENT.BASIC);

		// Test update method
		bit.content = TEST_CONTENT.SECONDARY;
		expect(bit.content).toBe(TEST_CONTENT.SECONDARY);

		// Test direct property assignment
		bit.content = TEST_CONTENT.EMPTY;
		expect(bit.content).toBe(TEST_CONTENT.EMPTY);
	});

	test('Text_Bit serialization and deserialization', () => {
		const test_id = Uuid.parse(undefined);
		const test_date = new Date().toISOString();

		// Create bit with all properties
		const original = zzz.registry.instantiate('Text_Bit', {
			id: test_id,
			created: test_date,
			type: 'text',
			content: TEST_CONTENT.BASIC,
			name: 'Test bit',
			has_xml_tag: true,
			xml_tag_name: 'test',
			start: 5,
			end: 15,
			enabled: false,
			title: 'Test Title',
			summary: 'Test Summary',
		});

		// Add attributes
		original.add_attribute({key: 'class', value: 'highlight'});

		// Serialize to JSON
		const json = original.to_json();

		// Create new bit from JSON
		const restored = zzz.registry.instantiate('Text_Bit', json);

		// Verify all properties were preserved
		expect(restored.id).toBe(test_id);
		expect(restored.created).toBe(test_date);
		expect(restored.content).toBe(TEST_CONTENT.BASIC);
		expect(restored.name).toBe('Test bit');
		expect(restored.has_xml_tag).toBe(true);
		expect(restored.xml_tag_name).toBe('test');
		expect(restored.start).toBe(5);
		expect(restored.end).toBe(15);
		expect(restored.enabled).toBe(false);
		expect(restored.title).toBe('Test Title');
		expect(restored.summary).toBe('Test Summary');
		expect(restored.attributes).toHaveLength(1);
		expect(restored.attributes[0].key).toBe('class');
		expect(restored.attributes[0].value).toBe('highlight');
	});

	test('Text_Bit cloning creates independent copy', () => {
		// Create original bit
		const original = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: TEST_CONTENT.BASIC,
			name: 'Original',
		});

		// Clone the bit
		const clone = original.clone();

		// Verify initial state is the same except id
		expect(clone.id).not.toBe(original.id);
		expect(clone.content).toBe(original.content);
		expect(clone.name).toBe(original.name);

		// Modify clone
		clone.content = TEST_CONTENT.SECONDARY;
		clone.name = 'Modified';

		// Verify original remains unchanged
		expect(original.content).toBe(TEST_CONTENT.BASIC);
		expect(original.name).toBe('Original');

		// Verify clone has new values
		expect(clone.content).toBe(TEST_CONTENT.SECONDARY);
		expect(clone.name).toBe('Modified');
	});
});

describe('Diskfile_Bit specific behavior', () => {
	test('Diskfile_Bit initialization and content access', () => {
		// Create a diskfile first
		const diskfile = zzz.diskfiles.add(
			zzz.registry.instantiate('Diskfile', {
				path: TEST_PATH,
				content: TEST_CONTENT.BASIC,
			}),
		);

		// Create diskfile bit that references the diskfile
		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path: TEST_PATH,
		});

		// Test basic properties
		expect(bit.type).toBe('diskfile');
		expect(bit.path).toBe(TEST_PATH);
		expect(bit.diskfile).toEqual(diskfile);
		expect(bit.content).toBe(TEST_CONTENT.BASIC);

		// Update content through bit
		bit.content = TEST_CONTENT.SECONDARY;

		// Verify both bit and diskfile were updated
		expect(bit.content).toBe(TEST_CONTENT.SECONDARY);
		expect(bit.diskfile?.content).toBe(TEST_CONTENT.SECONDARY);
	});

	test('Diskfile_Bit handles null path properly', () => {
		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path: null,
		});

		expect(bit.path).toBeNull();
		expect(bit.diskfile).toBeNull();
		expect(bit.content).toBeUndefined();
	});

	test('Diskfile_Bit handles changing path', () => {
		// Create two diskfiles
		const path1 = Diskfile_Path.parse('/path/to/file1.txt');
		const path2 = Diskfile_Path.parse('/path/to/file2.txt');

		zzz.diskfiles.add(
			zzz.registry.instantiate('Diskfile', {
				path: path1,
				content: 'File 1 content',
			}),
		);

		zzz.diskfiles.add(
			zzz.registry.instantiate('Diskfile', {
				path: path2,
				content: 'File 2 content',
			}),
		);

		// Create bit referencing first file
		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path: path1,
		});

		expect(bit.path).toBe(path1);
		expect(bit.content).toBe('File 1 content');

		// Change path to reference second file
		bit.path = path2;

		expect(bit.path).toBe(path2);
		expect(bit.content).toBe('File 2 content');
	});
});

describe('Sequence_Bit specific behavior', () => {
	test('Sequence_Bit initialization and content derivation', () => {
		// Create bits to be referenced
		const bit1 = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: 'First bit content',
		});

		const bit2 = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: 'Second bit content',
		});

		// Add to registry
		zzz.bits.items.add(bit1);
		zzz.bits.items.add(bit2);

		// Create sequence with references
		const sequence = zzz.registry.instantiate('Sequence_Bit', {
			type: 'sequence',
			items: [bit1.id, bit2.id],
		});

		// Test basic properties
		expect(sequence.type).toBe('sequence');
		expect(sequence.items).toEqual([bit1.id, bit2.id]);
		expect(sequence.bits).toEqual([bit1, bit2]);
		expect(sequence.content).toBe('First bit content\n\nSecond bit content');

		// Test content updates when referenced bits change
		bit1.content = 'Updated first bit';
		expect(sequence.content).toBe('Updated first bit\n\nSecond bit content');
	});

	test('Sequence_Bit item management methods', () => {
		// Create bits to be referenced
		const bit1 = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: 'First bit',
		});

		const bit2 = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: 'Second bit',
		});

		const bit3 = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: 'Third bit',
		});

		// Add to registry
		zzz.bits.items.add(bit1);
		zzz.bits.items.add(bit2);
		zzz.bits.items.add(bit3);

		// Create empty sequence
		const sequence = zzz.registry.instantiate('Sequence_Bit');

		// Test add method
		const add1 = sequence.add(bit1.id);
		expect(add1).toBe(true);
		expect(sequence.items).toEqual([bit1.id]);
		expect(sequence.bits).toEqual([bit1]);

		const add2 = sequence.add(bit2.id);
		expect(add2).toBe(true);
		expect(sequence.items).toEqual([bit1.id, bit2.id]);
		expect(sequence.bits).toEqual([bit1, bit2]);

		// Test adding duplicate (should return false)
		const add_duplicate = sequence.add(bit1.id);
		expect(add_duplicate).toBe(false);
		expect(sequence.items).toEqual([bit1.id, bit2.id]);

		// Test move method
		const move = sequence.move(bit1.id, 1);
		expect(move).toBe(true);
		expect(sequence.items).toEqual([bit2.id, bit1.id]);
		expect(sequence.bits).toEqual([bit2, bit1]);

		// Test remove method
		const remove = sequence.remove(bit2.id);
		expect(remove).toBe(true);
		expect(sequence.items).toEqual([bit1.id]);
		expect(sequence.bits).toEqual([bit1]);

		// Test operations with non-existent ID
		const nonexistent_id = Uuid.parse(undefined);
		expect(sequence.move(nonexistent_id, 0)).toBe(false);
		expect(sequence.remove(nonexistent_id)).toBe(false);
	});

	test('Sequence_Bit content assignment outputs console error', () => {
		const sequence = zzz.registry.instantiate('Sequence_Bit');

		// Temporarily override console.error
		const original_console_error = console.error;
		let error_called = false;

		console.error = () => {
			error_called = true;
		};

		// Try to update content directly, which should trigger error logging
		sequence.content = 'Test content';

		// Restore console.error
		console.error = original_console_error;

		// Verify warning was shown
		expect(error_called).toBe(true);
	});
});

describe('Common bit behavior across types', () => {
	test('Position markers work across bit types', () => {
		// Create different bit types
		const text_bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			content: TEST_CONTENT.BASIC,
			start: 5,
			end: 10,
		});

		const diskfile_bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path: TEST_PATH,
			start: 15,
			end: 20,
		});

		const sequence_bit = zzz.registry.instantiate('Sequence_Bit', {
			type: 'sequence',
			start: 25,
			end: 30,
		});

		// Verify initial positions
		expect(text_bit.start).toBe(5);
		expect(text_bit.end).toBe(10);

		expect(diskfile_bit.start).toBe(15);
		expect(diskfile_bit.end).toBe(20);

		expect(sequence_bit.start).toBe(25);
		expect(sequence_bit.end).toBe(30);

		// Update positions
		text_bit.start = 6;
		text_bit.end = 11;

		diskfile_bit.start = 16;
		diskfile_bit.end = 21;

		sequence_bit.start = 26;
		sequence_bit.end = 31;

		// Verify updated positions
		expect(text_bit.start).toBe(6);
		expect(text_bit.end).toBe(11);

		expect(diskfile_bit.start).toBe(16);
		expect(diskfile_bit.end).toBe(21);

		expect(sequence_bit.start).toBe(26);
		expect(sequence_bit.end).toBe(31);
	});

	test('XML tag properties work across bit types', () => {
		// Create bits with XML tag properties
		const text_bit = zzz.registry.instantiate('Text_Bit', {
			type: 'text',
			has_xml_tag: true,
			xml_tag_name: 'text-tag',
		});

		const diskfile_bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			has_xml_tag: true,
			xml_tag_name: 'file-tag',
		});

		const sequence_bit = zzz.registry.instantiate('Sequence_Bit', {
			type: 'sequence',
			has_xml_tag: true,
			xml_tag_name: 'sequence-tag',
		});

		// Verify initial XML tag properties
		expect(text_bit.has_xml_tag).toBe(true);
		expect(text_bit.xml_tag_name).toBe('text-tag');

		expect(diskfile_bit.has_xml_tag).toBe(true);
		expect(diskfile_bit.xml_tag_name).toBe('file-tag');

		expect(sequence_bit.has_xml_tag).toBe(true);
		expect(sequence_bit.xml_tag_name).toBe('sequence-tag');

		// Update XML tag properties
		text_bit.has_xml_tag = false;
		text_bit.xml_tag_name = '';

		diskfile_bit.xml_tag_name = 'updated-file-tag';

		sequence_bit.has_xml_tag = false;

		// Verify updated XML tag properties
		expect(text_bit.has_xml_tag).toBe(false);
		expect(text_bit.xml_tag_name).toBe('');

		expect(diskfile_bit.has_xml_tag).toBe(true);
		expect(diskfile_bit.xml_tag_name).toBe('updated-file-tag');

		expect(sequence_bit.has_xml_tag).toBe(false);
		expect(sequence_bit.xml_tag_name).toBe('sequence-tag');
	});
});
