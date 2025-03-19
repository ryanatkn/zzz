// @vitest-environment jsdom

import {test, expect, describe} from 'vitest';

import {Sequence_Bit, Text_Bit} from '$lib/bit.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';

// Helper to create a mock Zzz instance with a bits registry
const create_mock_zzz = () => {
	const bits_by_id = new Map();

	return {
		cells: new Map(),
		bits: {
			items: {
				by_id: bits_by_id,
				add: (bit: any) => bits_by_id.set(bit.id, bit),
				remove: (id: string) => bits_by_id.delete(id),
			},
		},
		diskfiles: {
			get_by_path: () => undefined,
		},
	} as any;
};

// Helper to create test bits
const create_test_bits = (mock_zzz: any, count = 3) => {
	const bits = [];

	for (let i = 0; i < count; i++) {
		const bit = new Text_Bit({
			zzz: mock_zzz,
			json: {
				type: 'text',
				content: `Content of bit ${i + 1}`,
				name: `Bit ${i + 1}`,
			},
		});

		// Add to registry
		mock_zzz.bits.items.add(bit);
		bits.push(bit);
	}

	return bits;
};

describe('Sequence_Bit initialization', () => {
	test('creates with empty items when no options provided', () => {
		const mock_zzz = create_mock_zzz();
		const bit = new Sequence_Bit({zzz: mock_zzz});

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
		const mock_zzz = create_mock_zzz();
		const test_bits = create_test_bits(mock_zzz);
		const test_id = Uuid.parse(undefined);
		const test_date = new Date().toISOString();

		const bit = new Sequence_Bit({
			zzz: mock_zzz,
			json: {
				id: test_id,
				type: 'sequence',
				created: test_date,
				name: 'Test sequence',
				items: [test_bits[0].id, test_bits[1].id],
				has_xml_tag: true,
				xml_tag_name: 'sequence',
				enabled: false,
				attributes: [{id: Uuid.parse(undefined), key: 'data-order', value: 'important'}],
			},
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
		const mock_zzz = create_mock_zzz();
		const test_bits = create_test_bits(mock_zzz);

		const sequence_bit = new Sequence_Bit({
			zzz: mock_zzz,
			json: {
				type: 'sequence',
				items: test_bits.map((b) => b.id),
			},
		});

		const expected_content = 'Content of bit 1\n\nContent of bit 2\n\nContent of bit 3';
		expect(sequence_bit.content).toBe(expected_content);
	});

	test('content updates when referenced bits change', () => {
		const mock_zzz = create_mock_zzz();
		const test_bits = create_test_bits(mock_zzz, 2);

		const sequence_bit = new Sequence_Bit({
			zzz: mock_zzz,
			json: {
				type: 'sequence',
				items: [test_bits[0].id, test_bits[1].id],
			},
		});

		expect(sequence_bit.content).toBe('Content of bit 1\n\nContent of bit 2');

		// Update content of first bit
		test_bits[0].content = 'Updated content';

		expect(sequence_bit.content).toBe('Updated content\n\nContent of bit 2');
	});

	test('content handles empty sequences', () => {
		const mock_zzz = create_mock_zzz();
		const sequence_bit = new Sequence_Bit({zzz: mock_zzz});

		expect(sequence_bit.content).toBe('');
	});

	test('content handles missing referenced bits', () => {
		const mock_zzz = create_mock_zzz();
		const nonexistent_id = Uuid.parse(undefined);

		const sequence_bit = new Sequence_Bit({
			zzz: mock_zzz,
			json: {
				type: 'sequence',
				items: [nonexistent_id],
			},
		});

		// Should gracefully handle missing bits
		expect(sequence_bit.content).toBe('');
		expect(sequence_bit.items).toEqual([nonexistent_id]);
		expect(sequence_bit.bits).toEqual([]);
	});
});

describe('Sequence_Bit item management', () => {
	test('add method adds items to sequence', () => {
		const mock_zzz = create_mock_zzz();
		const sequence_bit = new Sequence_Bit({zzz: mock_zzz});
		const test_bits = create_test_bits(mock_zzz);

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
	});

	test('add method prevents duplicates', () => {
		const mock_zzz = create_mock_zzz();
		const sequence_bit = new Sequence_Bit({zzz: mock_zzz});
		const test_bits = create_test_bits(mock_zzz, 1);

		// Add item once
		const result1 = sequence_bit.add(test_bits[0].id);
		expect(result1).toBe(true);
		expect(sequence_bit.items).toEqual([test_bits[0].id]);

		// Try adding the same item again
		const result2 = sequence_bit.add(test_bits[0].id);
		expect(result2).toBe(false); // Should return false for duplicate
		expect(sequence_bit.items).toEqual([test_bits[0].id]); // Items unchanged
	});

	test('remove method removes items from sequence', () => {
		const mock_zzz = create_mock_zzz();
		const test_bits = create_test_bits(mock_zzz);

		const sequence_bit = new Sequence_Bit({
			zzz: mock_zzz,
			json: {
				type: 'sequence',
				items: [test_bits[0].id, test_bits[1].id, test_bits[2].id],
			},
		});

		// Remove middle item
		const result1 = sequence_bit.remove(test_bits[1].id);
		expect(result1).toBe(true);
		expect(sequence_bit.items).toEqual([test_bits[0].id, test_bits[2].id]);

		// Remove first item
		const result2 = sequence_bit.remove(test_bits[0].id);
		expect(result2).toBe(true);
		expect(sequence_bit.items).toEqual([test_bits[2].id]);
	});

	test('remove method returns false for non-existent items', () => {
		const mock_zzz = create_mock_zzz();
		const test_bits = create_test_bits(mock_zzz, 1);
		const nonexistent_id = Uuid.parse(undefined);

		const sequence_bit = new Sequence_Bit({
			zzz: mock_zzz,
			json: {
				type: 'sequence',
				items: [test_bits[0].id],
			},
		});

		// Try removing non-existent item
		const result = sequence_bit.remove(nonexistent_id);
		expect(result).toBe(false);
		expect(sequence_bit.items).toEqual([test_bits[0].id]); // Items unchanged
	});

	test('move method changes item position', () => {
		const mock_zzz = create_mock_zzz();
		const test_bits = create_test_bits(mock_zzz);

		const sequence_bit = new Sequence_Bit({
			zzz: mock_zzz,
			json: {
				type: 'sequence',
				items: [test_bits[0].id, test_bits[1].id, test_bits[2].id],
			},
		});

		// Move first item to end
		const result1 = sequence_bit.move(test_bits[0].id, 2);
		expect(result1).toBe(true);
		expect(sequence_bit.items).toEqual([test_bits[1].id, test_bits[2].id, test_bits[0].id]);

		// Move last item to beginning
		const result2 = sequence_bit.move(test_bits[0].id, 0);
		expect(result2).toBe(true);
		expect(sequence_bit.items).toEqual([test_bits[0].id, test_bits[1].id, test_bits[2].id]);
	});

	test('move method returns false for non-existent items', () => {
		const mock_zzz = create_mock_zzz();
		const test_bits = create_test_bits(mock_zzz);
		const nonexistent_id = Uuid.parse(undefined);

		const sequence_bit = new Sequence_Bit({
			zzz: mock_zzz,
			json: {
				type: 'sequence',
				items: [test_bits[0].id, test_bits[1].id],
			},
		});

		// Try moving non-existent item
		const result = sequence_bit.move(nonexistent_id, 0);
		expect(result).toBe(false);
		expect(sequence_bit.items).toEqual([test_bits[0].id, test_bits[1].id]); // Items unchanged
	});
});

describe('Sequence_Bit serialization', () => {
	test('to_json includes all properties with correct values', () => {
		const mock_zzz = create_mock_zzz();
		const test_bits = create_test_bits(mock_zzz, 2);
		const test_id = Uuid.parse(undefined);
		const created = new Date().toISOString();

		const sequence_bit = new Sequence_Bit({
			zzz: mock_zzz,
			json: {
				id: test_id,
				created,
				type: 'sequence',
				name: 'Test sequence',
				items: [test_bits[0].id, test_bits[1].id],
			},
		});

		const json = sequence_bit.to_json();

		expect(json.id).toBe(test_id);
		expect(json.type).toBe('sequence');
		expect(json.created).toBe(created);
		expect(json.name).toBe('Test sequence');
		expect(json.items).toEqual([test_bits[0].id, test_bits[1].id]);
		expect(json.has_xml_tag).toBe(false);
		expect(json.enabled).toBe(true);
	});

	test('clone creates independent copy with same values', () => {
		const mock_zzz = create_mock_zzz();
		const test_bits = create_test_bits(mock_zzz, 2);

		const original = new Sequence_Bit({
			zzz: mock_zzz,
			json: {
				type: 'sequence',
				name: 'Original sequence',
				items: [test_bits[0].id],
			},
		});

		const clone = original.clone();

		// Verify they have same initial values
		expect(clone.id).toBe(original.id);
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
		const mock_zzz = create_mock_zzz();
		const bit = new Sequence_Bit({
			zzz: mock_zzz,
		});

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
		const fake_update = bit.update_attribute(Uuid.parse(undefined), {key: 'test', value: 'test'});
		expect(fake_update).toBe(false);
	});
});

describe('Sequence_Bit edge cases', () => {
	test('handles removal of bits from registry', () => {
		const mock_zzz = create_mock_zzz();
		const test_bits = create_test_bits(mock_zzz, 3);

		const sequence_bit = new Sequence_Bit({
			zzz: mock_zzz,
			json: {
				type: 'sequence',
				items: [test_bits[0].id, test_bits[1].id, test_bits[2].id],
			},
		});

		// Initially has all three bits
		expect(sequence_bit.bits).toHaveLength(3);

		// Remove a bit from the registry (but not from sequence items)
		mock_zzz.bits.items.remove(test_bits[1].id);

		// The bits array should only have the remaining two
		expect(sequence_bit.items).toHaveLength(3); // items list is unchanged
		// TODO BLOCK what should happen here? shouldnt it be removed, or set to a placeholder?
		expect(sequence_bit.bits).toHaveLength(2); // derived bits list should exclude missing bit
		expect(sequence_bit.bits[0]).toBe(test_bits[0]);
		expect(sequence_bit.bits[1]).toBe(test_bits[2]);

		// Content should only include the found bits
		expect(sequence_bit.content).toBe('Content of bit 1\n\nContent of bit 3');
	});

	test('content handles nested sequences', () => {
		const mock_zzz = create_mock_zzz();
		const test_bits = create_test_bits(mock_zzz, 2);

		// Create a nested sequence
		const inner_sequence = new Sequence_Bit({
			zzz: mock_zzz,
			json: {
				type: 'sequence',
				name: 'Inner sequence',
				items: [test_bits[0].id],
			},
		});

		mock_zzz.bits.items.add(inner_sequence);

		// Create outer sequence that references the inner sequence
		const outer_sequence = new Sequence_Bit({
			zzz: mock_zzz,
			json: {
				type: 'sequence',
				name: 'Outer sequence',
				items: [inner_sequence.id, test_bits[1].id],
			},
		});

		// Content should combine all bits correctly
		expect(outer_sequence.content).toBe('Content of bit 1\n\nContent of bit 2');
	});
});
