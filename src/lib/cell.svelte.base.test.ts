// @vitest-environment jsdom

import {test, expect, vi, beforeEach, describe} from 'vitest';
import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Datetime_Now, Uuid} from '$lib/zod_helpers.js';
import {Zzz} from '$lib/zzz.svelte.js';
import {monkeypatch_zzz_for_tests} from '$lib/test_helpers.js';

// Constants for testing
const TEST_ID = 'a0000000-0000-0000-0000-000000000001' as Uuid;
const TEST_DATE = Datetime_Now.parse(undefined);

// Basic schema for testing that extends Cell_Json
const Test_Schema = Cell_Json.extend({
	text: z.string().default(''),
	number: z.number().default(0),
	items: z.array(z.string()).default(() => []),
	flag: z.boolean().default(true),
}).strict();

// Basic test cell implementation
class Basic_Test_Cell extends Cell<typeof Test_Schema> {
	text: string = $state()!;
	number: number = $state()!;
	items: Array<string> = $state()!;
	flag: boolean = $state()!;

	constructor(options: Cell_Options<typeof Test_Schema>) {
		super(Test_Schema, options);
		this.init();
	}
}

// Test suite variables
let zzz: Zzz;

beforeEach(() => {
	// Create a real Zzz instance for each test
	zzz = monkeypatch_zzz_for_tests(new Zzz());
	vi.clearAllMocks();
});

describe('Cell initialization', () => {
	test('initializes with provided json', () => {
		const test_cell = new Basic_Test_Cell({
			zzz,
			json: {
				id: TEST_ID,
				created: TEST_DATE,
				text: 'Sample',
				number: 42,
				items: ['item1', 'item2'],
			},
		});

		// Verify basic properties
		expect(test_cell.id).toBe(TEST_ID);
		expect(test_cell.created).toBe(TEST_DATE);
		expect(test_cell.updated).toBeNull();
		expect(test_cell.text).toBe('Sample');
		expect(test_cell.number).toBe(42);
		expect(test_cell.items).toEqual(['item1', 'item2']);

		// Verify cell was registered
		expect(zzz.cells.has(TEST_ID)).toBe(true);
		expect(zzz.cells.get(TEST_ID)).toBe(test_cell);
	});

	test('uses default values when json is empty', () => {
		const test_cell = new Basic_Test_Cell({
			zzz,
		});

		// Should use schema defaults
		expect(test_cell.id).toBeDefined();
		expect(test_cell.created).toBeDefined();
		expect(test_cell.updated).toBeNull();
		expect(test_cell.text).toBe('');
		expect(test_cell.number).toBe(0);
		expect(test_cell.items).toEqual([]);
		expect(test_cell.flag).toBe(true);
	});

	test('derived schema properties are correctly calculated', () => {
		const test_cell = new Basic_Test_Cell({
			zzz,
			json: {
				id: TEST_ID,
			},
		});

		// Check if schema keys contain expected fields
		expect(test_cell.schema_keys).toContain('id');
		expect(test_cell.schema_keys).toContain('text');
		expect(test_cell.schema_keys).toContain('number');
		expect(test_cell.schema_keys).toContain('items');

		// Check if field schemas are correctly mapped
		expect(test_cell.field_schemas.size).toBeGreaterThan(0);
		expect(test_cell.field_schemas.has('text')).toBe(true);
		expect(test_cell.field_schemas.has('number')).toBe(true);

		// Test schema info for an array type
		const items_info = test_cell.field_schema_info.get('items');
		expect(items_info?.is_array).toBe(true);
		expect(items_info?.type).toBe('ZodArray');

		// Test schema info for a scalar type
		const text_info = test_cell.field_schema_info.get('text');
		expect(text_info?.is_array).toBe(false);
		expect(text_info?.type).toBe('ZodString');
	});
});

describe('Cell registry lifecycle', () => {
	test('cell is automatically registered on initialization', () => {
		const cell_id = Uuid.parse(undefined);

		const test_cell = new Basic_Test_Cell({
			zzz,
			json: {
				id: cell_id,
				created: TEST_DATE,
			},
		});

		// Cell should be registered automatically in init()
		expect(zzz.cells.has(cell_id)).toBe(true);
		expect(zzz.cells.get(cell_id)).toBe(test_cell);
	});

	test('dispose removes from registry', () => {
		const cell_id = Uuid.parse(undefined);

		const test_cell = new Basic_Test_Cell({
			zzz,
			json: {
				id: cell_id,
				created: TEST_DATE,
			},
		});

		// Verify initial registration
		expect(zzz.cells.has(cell_id)).toBe(true);

		// Dispose cell
		test_cell.dispose();

		// Should be removed from registry
		expect(zzz.cells.has(cell_id)).toBe(false);
	});

	test('dispose is safe to call multiple times', () => {
		const cell_id = Uuid.parse(undefined);

		const test_cell = new Basic_Test_Cell({
			zzz,
			json: {
				id: cell_id,
			},
		});

		// First dispose
		test_cell.dispose();
		expect(zzz.cells.has(cell_id)).toBe(false);

		// Second dispose should not throw
		expect(() => test_cell.dispose()).not.toThrow();
	});
});

describe('Cell id handling', () => {
	// Define a test schema with required type field for these tests
	const Id_Test_Schema = z.object({
		id: Uuid,
		type: z.literal('test').default('test'),
		content: z.string().default(''),
		version: z.number().default(0),
	});

	// Test implementation of the Cell class with id-specific tests
	class Id_Test_Cell extends Cell<typeof Id_Test_Schema> {
		type: string = $state()!;
		content: string = $state()!;
		version: number = $state()!;

		constructor(options: {zzz: Zzz; json?: any}) {
			super(Id_Test_Schema, options);
			this.init();
		}
	}

	test('set_json overwrites id when provided in input', () => {
		// Create initial cell
		const cell = new Id_Test_Cell({zzz});
		const initial_id = cell.id;

		// Verify initial state
		expect(cell.id).toBe(initial_id);

		// Create a new id to set
		const new_id = Uuid.parse(undefined);
		expect(new_id).not.toBe(initial_id);

		// Set new id through set_json
		cell.set_json({
			id: new_id,
			type: 'test',
			content: 'New content',
			version: 2,
		});

		// Verify id was changed to the new value
		expect(cell.id).toBe(new_id);
		expect(cell.id).not.toBe(initial_id);
	});

	test('set_json_partial updates id when included in partial update', () => {
		// Create initial cell
		const cell = new Id_Test_Cell({zzz});
		const initial_id = cell.id;

		// Create a new id to set
		const new_id = Uuid.parse(undefined);

		// Update only the id
		cell.set_json_partial({
			id: new_id,
			version: 3,
		});

		// Verify id was updated and other properties preserved
		expect(cell.id).toBe(new_id);
		expect(cell.id).not.toBe(initial_id);
		expect(cell.type).toBe('test');
		expect(cell.content).toBe('');
		expect(cell.version).toBe(3);
	});

	test('set_json_partial preserves id when not included in partial update', () => {
		// Create initial cell
		const cell = new Id_Test_Cell({zzz});
		const initial_id = cell.id;
		const initial_content = '';

		// Update content but not id
		cell.set_json_partial({
			content: 'Partial update content',
		});

		// Verify id preserved and content updated
		expect(cell.id).toBe(initial_id);
		expect(cell.content).toBe('Partial update content');
		expect(cell.content).not.toBe(initial_content);
	});

	test('schema validation rejects invalid id formats', () => {
		// Create initial cell
		const cell = new Id_Test_Cell({zzz});

		// Attempt to set invalid id
		expect(() => {
			cell.set_json_partial({
				id: 'not-a-valid-uuid' as any,
			});
		}).toThrow();
	});

	test('clone creates a new id instead of copying the original', () => {
		// Create cell with initial values
		const cell = new Id_Test_Cell({
			zzz,
			json: {
				type: 'test',
				content: 'Original content',
				version: 1,
			},
		});
		const original_id = cell.id;

		// Clone the cell
		const cloned_cell = cell.clone();

		// Verify clone has new id but same content
		expect(cloned_cell.id).not.toBe(original_id);
		expect(cloned_cell.content).toBe('Original content');
		expect(cloned_cell.version).toBe(1);

		// Verify changing clone doesn't affect original
		cloned_cell.content = 'Changed in clone';
		expect(cell.content).toBe('Original content');
	});
});

describe('Cell serialization', () => {
	test('to_json creates correct representation', () => {
		const test_cell = new Basic_Test_Cell({
			zzz,
			json: {
				id: TEST_ID,
				created: TEST_DATE,
				text: 'JSON Test',
				number: 100,
				items: ['value1', 'value2'],
			},
		});

		const json = test_cell.to_json();

		expect(json.id).toBe(TEST_ID);
		expect(json.created).toBe(TEST_DATE);
		expect(json.text).toBe('JSON Test');
		expect(json.number).toBe(100);
		expect(json.items).toEqual(['value1', 'value2']);
	});

	test('toJSON method works with JSON.stringify', () => {
		const test_cell = new Basic_Test_Cell({
			zzz,
			json: {
				id: TEST_ID,
				text: 'Stringify Test',
			},
		});

		const stringified = JSON.stringify(test_cell);
		const parsed = JSON.parse(stringified);

		expect(parsed.id).toBe(TEST_ID);
		expect(parsed.text).toBe('Stringify Test');
	});

	test('derived json properties update when cell changes', () => {
		const test_cell = new Basic_Test_Cell({
			zzz,
			json: {
				id: TEST_ID,
				text: 'Initial',
				number: 10,
			},
		});

		// Check initial values
		expect(test_cell.json.text).toBe('Initial');
		expect(test_cell.json.number).toBe(10);

		// Update values
		test_cell.text = 'Updated';
		test_cell.number = 20;

		// Check derived properties updated
		expect(test_cell.json.text).toBe('Updated');
		expect(test_cell.json.number).toBe(20);

		// Check derived serialized JSON
		const parsed = JSON.parse(test_cell.json_serialized);
		expect(parsed.text).toBe('Updated');
		expect(parsed.number).toBe(20);
	});
});

describe('Cell modification methods', () => {
	test('set_json updates properties', () => {
		const test_cell = new Basic_Test_Cell({
			zzz,
			json: {
				id: TEST_ID,
				text: 'Initial',
			},
		});

		// Update using set_json
		test_cell.set_json({
			text: 'Updated via set_json',
			number: 50,
			items: ['new1', 'new2'],
		});

		expect(test_cell.text).toBe('Updated via set_json');
		expect(test_cell.number).toBe(50);
		expect(test_cell.items).toEqual(['new1', 'new2']);
		expect(test_cell.id).not.toBe(TEST_ID); // id should be new
	});

	test('set_json rejects invalid data', () => {
		const test_cell = new Basic_Test_Cell({zzz});

		// Should reject invalid data with a schema error
		expect(() => test_cell.set_json({number: 'not a number' as any})).toThrow();
	});

	test('set_json_partial updates only specified properties', () => {
		const test_cell = new Basic_Test_Cell({
			zzz,
			json: {
				id: TEST_ID,
				text: 'Initial text',
				number: 10,
				items: ['item1', 'item2'],
				flag: true,
			},
		});

		// Update only text and number
		test_cell.set_json_partial({
			text: 'Updated text',
			number: 20,
		});

		// Verify updated properties
		expect(test_cell.text).toBe('Updated text');
		expect(test_cell.number).toBe(20);

		// Verify untouched properties
		expect(test_cell.items).toEqual(['item1', 'item2']);
		expect(test_cell.flag).toBe(true);
		expect(test_cell.id).toBe(TEST_ID);
	});

	test('set_json_partial handles null or undefined input', () => {
		const test_cell = new Basic_Test_Cell({
			zzz,
			json: {
				id: TEST_ID,
				text: 'Initial',
			},
		});

		// These should not throw errors
		expect(() => test_cell.set_json_partial(null!)).not.toThrow();
		expect(() => test_cell.set_json_partial(undefined!)).not.toThrow();

		// Properties should remain unchanged
		expect(test_cell.id).toBe(TEST_ID);
		expect(test_cell.text).toBe('Initial');
	});

	test('set_json_partial validates merged data against schema', () => {
		const test_cell = new Basic_Test_Cell({
			zzz,
			json: {
				id: TEST_ID,
				text: 'Initial',
			},
		});

		// Should reject invalid data with a schema error
		expect(() => test_cell.set_json_partial({number: 'not a number' as any})).toThrow();

		// Original values should remain unchanged after failed update
		expect(test_cell.text).toBe('Initial');
	});
});

describe('Cell date formatting', () => {
	test('formats dates correctly', () => {
		const now = new Date();
		const created = now.toISOString();
		const updated = new Date(now.getTime() + 10000).toISOString();

		const test_cell = new Basic_Test_Cell({
			zzz,
			json: {
				id: TEST_ID,
				created,
				updated,
			},
		});

		// Verify date objects
		expect(test_cell.created_date).toBeInstanceOf(Date);
		expect(test_cell.updated_date).toBeInstanceOf(Date);

		// Verify formatted strings exist
		expect(test_cell.created_formatted_short_date).not.toBeNull();
		expect(test_cell.created_formatted_date).not.toBeNull();
		expect(test_cell.created_formatted_time).not.toBeNull();

		expect(test_cell.updated_formatted_short_date).not.toBeNull();
		expect(test_cell.updated_formatted_date).not.toBeNull();
		expect(test_cell.updated_formatted_time).not.toBeNull();
	});

	test('handles null updated date', () => {
		const test_cell = new Basic_Test_Cell({
			zzz,
			json: {
				id: TEST_ID,
				created: TEST_DATE,
				updated: null,
			},
		});

		expect(test_cell.updated_date).toBeNull();
		expect(test_cell.updated_formatted_short_date).toBeNull();
		expect(test_cell.updated_formatted_date).toBeNull();
		expect(test_cell.updated_formatted_time).toBeNull();
	});
});

describe('Cell cloning', () => {
	test('clone creates independent copy', () => {
		const original = new Basic_Test_Cell({
			zzz,
			json: {
				id: TEST_ID,
				text: 'Original',
				number: 42,
				items: ['value1'],
			},
		});

		const clone = original.clone();

		// Should have same values
		expect(clone.text).toBe('Original');
		expect(clone.number).toBe(42);
		expect(clone.items).toEqual(['value1']);

		// But be a different instance
		expect(clone).not.toBe(original);
		expect(clone.id).not.toBe(original.id); // Should have new id

		// Changes to one shouldn't affect the other
		clone.text = 'Changed';
		clone.number = 100;
		clone.items.push('value2');

		expect(original.text).toBe('Original');
		expect(original.number).toBe(42);
		expect(original.items).toEqual(['value1']);
	});

	test('clone registers new instance in registry', () => {
		const original = new Basic_Test_Cell({
			zzz,
			json: {
				id: TEST_ID,
			},
		});

		const clone = original.clone();

		// Both instances should be registered
		expect(zzz.cells.has(original.id)).toBe(true);
		expect(zzz.cells.has(clone.id)).toBe(true);
		expect(zzz.cells.get(clone.id)).toBe(clone);
	});
});

describe('Schema validation', () => {
	test('json_parsed validates cell state', () => {
		const test_cell = new Basic_Test_Cell({
			zzz,
			json: {
				id: TEST_ID,
				text: 'Valid',
			},
		});

		// Initial state should be valid
		expect(test_cell.json_parsed.success).toBe(true);

		// Invalid initialization should throw
		expect(
			() =>
				new Basic_Test_Cell({
					zzz,
					json: {
						id: TEST_ID,
						text: 123 as any,
					},
				}),
		).toThrow();
	});
});
