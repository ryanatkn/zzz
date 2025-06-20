// @slop claude_opus_4

// @vitest-environment jsdom

import {test, expect, describe, beforeEach} from 'vitest';

import {Text_Bit} from '$lib/bit.svelte.js';
import {create_uuid, get_datetime_now} from '$lib/zod_helpers.js';
import {Frontend} from '$lib/frontend.svelte.js';
import {monkeypatch_zzz_for_tests} from '$lib/test_helpers.js';

// Test suite variables
let app: Frontend;
let test_bits: Array<Text_Bit>;

// Setup function to create a real Zzz instance and test bits
beforeEach(() => {
	// Create a real Zzz instance
	app = monkeypatch_zzz_for_tests(new Frontend());

	// Create real Text_Bit instances using the registry
	test_bits = [];
	for (let i = 0; i < 3; i++) {
		const bit = app.cell_registry.instantiate('Text_Bit', {
			type: 'text',
			content: `Content of bit ${i + 1}`,
			name: `Bit ${i + 1}`,
		});
		// Add bits to the registry
		app.bits.items.add(bit);
		test_bits.push(bit);
	}
});

describe('Sequence_Bit initialization', () => {
	test('creates with empty items when no options provided', () => {
		const bit = app.cell_registry.instantiate('Sequence_Bit');

		expect(bit.type).toBe('sequence');
		expect(bit.items).toEqual([]);
		expect(bit.bits).toEqual([]);
		expect(bit.content).toBe('');
		expect(bit.name).toBe('');
		expect(bit.enabled).toBe(true);
		expect(bit.has_xml_tag).toBe(false);
		expect(bit.xml_tag_name).toBe('');
		expect(bit.attributes).toEqual([]);
	});

	test('initializes from json with items', () => {
		const test_id = create_uuid();
		const test_date = get_datetime_now();

		const bit = app.cell_registry.instantiate('Sequence_Bit', {
			id: test_id,
			created: test_date,
			type: 'sequence',
			name: 'Test sequence',
			items: [test_bits[0].id, test_bits[1].id],
			has_xml_tag: true,
			xml_tag_name: 'sequence',
			enabled: false,
			attributes: [{id: create_uuid(), key: 'data-order', value: 'important'}],
		});

		expect(bit.id).toBe(test_id);
		expect(bit.name).toBe('Test sequence');
		expect(bit.items).toHaveLength(2);
		expect(bit.items[0]).toBe(test_bits[0].id);
		expect(bit.items[1]).toBe(test_bits[1].id);
		expect(bit.bits).toHaveLength(2);
		expect(bit.bits[0]).toBe(test_bits[0]);
		expect(bit.bits[1]).toBe(test_bits[1]);
		expect(bit.has_xml_tag).toBe(true);
		expect(bit.xml_tag_name).toBe('sequence');
		expect(bit.enabled).toBe(false);
		expect(bit.attributes).toHaveLength(1);
		expect(bit.attributes[0].key).toBe('data-order');
	});
});

describe('Sequence_Bit content derivation', () => {
	test('content combines referenced bits with double newlines', () => {
		const sequence_bit = app.cell_registry.instantiate('Sequence_Bit', {
			type: 'sequence',
			items: test_bits.map((b) => b.id),
		});

		const expected_content = 'Content of bit 1\n\nContent of bit 2\n\nContent of bit 3';
		expect(sequence_bit.content).toBe(expected_content);
	});

	test('content updates when referenced bits change', () => {
		const sequence_bit = app.cell_registry.instantiate('Sequence_Bit', {
			type: 'sequence',
			items: [test_bits[0].id, test_bits[1].id],
		});

		// Initial content
		expect(sequence_bit.content).toBe('Content of bit 1\n\nContent of bit 2');

		// Update content of first bit
		test_bits[0].content = 'Updated content';

		// Verify the sequence content updated
		expect(sequence_bit.content).toBe('Updated content\n\nContent of bit 2');
	});

	test('content handles empty sequences', () => {
		const sequence_bit = app.cell_registry.instantiate('Sequence_Bit');
		expect(sequence_bit.content).toBe('');
	});

	test('content handles missing referenced bits', () => {
		const nonexistent_id = create_uuid();

		const sequence_bit = app.cell_registry.instantiate('Sequence_Bit', {
			type: 'sequence',
			items: [nonexistent_id],
		});

		// Should gracefully handle missing bits
		expect(sequence_bit.content).toBe('');
		expect(sequence_bit.items).toEqual([nonexistent_id]);
		expect(sequence_bit.bits).toEqual([]);
	});
});

describe('Sequence_Bit item management', () => {
	test('add method adds items to sequence', () => {
		const sequence_bit = app.cell_registry.instantiate('Sequence_Bit');

		// Initially empty
		expect(sequence_bit.items).toEqual([]);

		// Add first item
		const result1 = sequence_bit.add(test_bits[0].id);
		expect(result1).toBe(true);
		expect(sequence_bit.items).toEqual([test_bits[0].id]);

		// Add second item
		const result2 = sequence_bit.add(test_bits[1].id);
		expect(result2).toBe(true);
		expect(sequence_bit.items).toEqual([test_bits[0].id, test_bits[1].id]);

		// Verify bits array reflects the changes
		expect(sequence_bit.bits).toEqual([test_bits[0], test_bits[1]]);
	});

	test('add method prevents duplicates', () => {
		const sequence_bit = app.cell_registry.instantiate('Sequence_Bit');

		// Add item once
		const result1 = sequence_bit.add(test_bits[0].id);
		expect(result1).toBe(true);
		expect(sequence_bit.items).toEqual([test_bits[0].id]);

		// Try adding the same item again
		const result2 = sequence_bit.add(test_bits[0].id);
		expect(result2).toBe(false); // Should return false for duplicate
		expect(sequence_bit.items).toEqual([test_bits[0].id]); // Items unchanged

		// Verify bits array has one item
		expect(sequence_bit.bits).toEqual([test_bits[0]]);
	});

	test('remove method removes items from sequence', () => {
		const sequence_bit = app.cell_registry.instantiate('Sequence_Bit', {
			type: 'sequence',
			items: [test_bits[0].id, test_bits[1].id, test_bits[2].id],
		});

		// Initial state
		expect(sequence_bit.items).toHaveLength(3);
		expect(sequence_bit.bits).toHaveLength(3);

		// Remove middle item
		const result1 = sequence_bit.remove(test_bits[1].id);
		expect(result1).toBe(true);
		expect(sequence_bit.items).toEqual([test_bits[0].id, test_bits[2].id]);
		expect(sequence_bit.bits).toEqual([test_bits[0], test_bits[2]]);

		// Remove first item
		const result2 = sequence_bit.remove(test_bits[0].id);
		expect(result2).toBe(true);
		expect(sequence_bit.items).toEqual([test_bits[2].id]);
		expect(sequence_bit.bits).toEqual([test_bits[2]]);
	});

	test('remove method returns false for non-existent items', () => {
		const nonexistent_id = create_uuid();
		const sequence_bit = app.cell_registry.instantiate('Sequence_Bit', {
			type: 'sequence',
			items: [test_bits[0].id],
		});

		// Try removing non-existent item
		const result = sequence_bit.remove(nonexistent_id);
		expect(result).toBe(false);
		expect(sequence_bit.items).toEqual([test_bits[0].id]); // Items unchanged
		expect(sequence_bit.bits).toEqual([test_bits[0]]);
	});

	test('move method changes item position', () => {
		const sequence_bit = app.cell_registry.instantiate('Sequence_Bit', {
			type: 'sequence',
			items: [test_bits[0].id, test_bits[1].id, test_bits[2].id],
		});

		// Initial state
		expect(sequence_bit.items).toEqual([test_bits[0].id, test_bits[1].id, test_bits[2].id]);
		expect(sequence_bit.bits).toEqual([test_bits[0], test_bits[1], test_bits[2]]);

		// Move first item to end
		const result1 = sequence_bit.move(test_bits[0].id, 2);
		expect(result1).toBe(true);
		expect(sequence_bit.items).toEqual([test_bits[1].id, test_bits[2].id, test_bits[0].id]);
		expect(sequence_bit.bits).toEqual([test_bits[1], test_bits[2], test_bits[0]]);

		// Move last item to beginning
		const result2 = sequence_bit.move(test_bits[0].id, 0);
		expect(result2).toBe(true);
		expect(sequence_bit.items).toEqual([test_bits[0].id, test_bits[1].id, test_bits[2].id]);
		expect(sequence_bit.bits).toEqual([test_bits[0], test_bits[1], test_bits[2]]);
	});

	test('move method returns false for non-existent items', () => {
		const nonexistent_id = create_uuid();
		const sequence_bit = app.cell_registry.instantiate('Sequence_Bit', {
			type: 'sequence',
			items: [test_bits[0].id, test_bits[1].id],
		});

		// Initial state
		const original_items = [...sequence_bit.items];
		const original_bits = [...sequence_bit.bits];

		// Try moving non-existent item
		const result = sequence_bit.move(nonexistent_id, 0);
		expect(result).toBe(false);
		expect(sequence_bit.items).toEqual(original_items); // Items unchanged
		expect(sequence_bit.bits).toEqual(original_bits);
	});

	test('update_content method logs warning in development', () => {
		const sequence_bit = app.cell_registry.instantiate('Sequence_Bit');

		// Save original console.error
		const original_console_error = console.error;
		let error_called = false;

		// Mock console.error
		console.error = () => {
			error_called = true;
		};

		// Assign content, which should log an error
		sequence_bit.content = 'This should not work';

		// Restore console.error
		console.error = original_console_error;

		// Verify error was logged
		expect(error_called).toBe(true);
	});

	test('update_content method logs warning in development', () => {
		const sequence_bit = app.cell_registry.instantiate('Sequence_Bit');

		// Save original console.error
		const original_console_error = console.error;
		let error_called = false;

		// Mock console.error
		console.error = () => {
			error_called = true;
		};

		// Call content setter, which should log an error
		sequence_bit.content = 'This should not work';

		// Restore console.error
		console.error = original_console_error;

		// Verify error was logged
		expect(error_called).toBe(true);
	});
});

describe('Sequence_Bit serialization', () => {
	test('to_json includes all properties with correct values', () => {
		const test_id = create_uuid();
		const created = get_datetime_now();

		const sequence_bit = app.cell_registry.instantiate('Sequence_Bit', {
			id: test_id,
			created,
			type: 'sequence',
			name: 'Test sequence',
			items: [test_bits[0].id, test_bits[1].id],
			title: 'Sequence title',
			summary: 'Sequence summary',
			start: 10,
			end: 50,
		});

		const json = sequence_bit.to_json();

		expect(json.id).toBe(test_id);
		expect(json.type).toBe('sequence');
		expect(json.created).toBe(created);
		expect(json.name).toBe('Test sequence');
		expect(json.items).toEqual([test_bits[0].id, test_bits[1].id]);
		expect(json.has_xml_tag).toBe(false);
		expect(json.enabled).toBe(true);
		expect(json.title).toBe('Sequence title');
		expect(json.summary).toBe('Sequence summary');
		expect(json.start).toBe(10);
		expect(json.end).toBe(50);
	});

	test('clone creates independent copy with same values', () => {
		const original = app.cell_registry.instantiate('Sequence_Bit', {
			type: 'sequence',
			name: 'Original sequence',
			items: [test_bits[0].id],
		});

		const clone = original.clone();

		// Verify they have same initial values except for id
		expect(clone.id).not.toBe(original.id);
		expect(clone.items).toEqual([test_bits[0].id]);
		expect(clone.name).toBe('Original sequence');

		// Verify they're independent objects
		clone.name = 'Modified sequence';
		clone.add(test_bits[1].id);

		expect(original.name).toBe('Original sequence');
		expect(original.items).toEqual([test_bits[0].id]);
		expect(clone.name).toBe('Modified sequence');
		expect(clone.items).toEqual([test_bits[0].id, test_bits[1].id]);
	});
});

describe('Sequence_Bit attribute management', () => {
	test('can add, update and remove attributes', () => {
		const bit = app.cell_registry.instantiate('Sequence_Bit');

		// Add attribute
		bit.add_attribute({key: 'role', value: 'container'});
		expect(bit.attributes).toHaveLength(1);
		expect(bit.attributes[0].key).toBe('role');
		expect(bit.attributes[0].value).toBe('container');

		const attr_id = bit.attributes[0].id;

		// Update attribute
		const updated = bit.update_attribute(attr_id, {value: 'section'});
		expect(updated).toBe(true);
		expect(bit.attributes[0].key).toBe('role');
		expect(bit.attributes[0].value).toBe('section');

		// Remove attribute
		bit.remove_attribute(attr_id);
		expect(bit.attributes).toHaveLength(0);

		// Attempting to update non-existent attribute returns false
		const fake_update = bit.update_attribute(create_uuid(), {key: 'test', value: 'test'});
		expect(fake_update).toBe(false);
	});

	test('updates attribute key and value together', () => {
		const bit = app.cell_registry.instantiate('Sequence_Bit');

		bit.add_attribute({key: 'class', value: 'highlight'});
		const attr_id = bit.attributes[0].id;

		// Update both key and value
		const updated = bit.update_attribute(attr_id, {key: 'data-type', value: 'important'});
		expect(updated).toBe(true);
		expect(bit.attributes[0].key).toBe('data-type');
		expect(bit.attributes[0].value).toBe('important');
	});
});

describe('Sequence_Bit edge cases', () => {
	test('handles removal of bits from registry', () => {
		const sequence_bit = app.cell_registry.instantiate('Sequence_Bit', {
			type: 'sequence',
			items: [test_bits[0].id, test_bits[1].id, test_bits[2].id],
		});

		// Initially has all three bits
		expect(sequence_bit.bits).toHaveLength(3);
		expect(sequence_bit.content).toBe('Content of bit 1\n\nContent of bit 2\n\nContent of bit 3');

		// Remove a bit from the registry (but not from sequence items)
		app.bits.items.remove(test_bits[1].id);

		// The bits array should only have the remaining two
		expect(sequence_bit.items).toHaveLength(3); // items list is unchanged
		expect(sequence_bit.bits).toHaveLength(2); // derived bits list should exclude missing bit
		expect(sequence_bit.bits[0]).toBe(test_bits[0]);
		expect(sequence_bit.bits[1]).toBe(test_bits[2]);

		// Content should only include the found bits
		expect(sequence_bit.content).toBe('Content of bit 1\n\nContent of bit 3');
	});

	test('content handles nested sequences', () => {
		// Create a nested sequence
		const inner_sequence = app.cell_registry.instantiate('Sequence_Bit', {
			type: 'sequence',
			name: 'Inner sequence',
			items: [test_bits[0].id],
		});

		app.bits.items.add(inner_sequence);

		// Create outer sequence that references the inner sequence
		const outer_sequence = app.cell_registry.instantiate('Sequence_Bit', {
			type: 'sequence',
			name: 'Outer sequence',
			items: [inner_sequence.id, test_bits[1].id],
		});

		// Content should combine all bits correctly
		expect(outer_sequence.content).toBe('Content of bit 1\n\nContent of bit 2');
	});

	test('handles empty string content in referenced bits', () => {
		// Create a bit with empty content
		const empty_bit = app.cell_registry.instantiate('Text_Bit', {
			type: 'text',
			content: '',
			name: 'Empty bit',
		});
		app.bits.items.add(empty_bit);

		// Create sequence with normal and empty bits
		const sequence_bit = app.cell_registry.instantiate('Sequence_Bit', {
			type: 'sequence',
			items: [test_bits[0].id, empty_bit.id, test_bits[1].id],
		});

		// Content should handle the empty bit correctly
		expect(sequence_bit.content).toBe('Content of bit 1\n\n\n\nContent of bit 2');
	});

	test('length, tokens and token_count properties are derived from content', () => {
		const sequence_bit = app.cell_registry.instantiate('Sequence_Bit', {
			type: 'sequence',
			items: [test_bits[0].id, test_bits[1].id],
		});

		// Get the expected properties
		const expected_content = 'Content of bit 1\n\nContent of bit 2';

		// Check length
		expect(sequence_bit.length).toBe(expected_content.length);

		// Check tokens
		expect(sequence_bit.token_count).toBeGreaterThan(0);
		expect(sequence_bit.token_count).toBe(sequence_bit.token_count);

		// Update content and verify properties update
		test_bits[0].content = 'New shorter text';

		const new_expected_content = 'New shorter text\n\nContent of bit 2';
		expect(sequence_bit.length).toBe(new_expected_content.length);
	});
});
