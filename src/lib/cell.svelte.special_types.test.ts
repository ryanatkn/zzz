// @slop claude_opus_4

// @vitest-environment jsdom

import {test, expect, vi, beforeEach} from 'vitest';
import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json, type Schema_Keys} from '$lib/cell_types.js';
import {Datetime_Now, get_datetime_now, create_uuid, Uuid_With_Default} from '$lib/zod_helpers.js';
import {Frontend} from '$lib/frontend.svelte.js';
import {monkeypatch_zzz_for_tests} from '$lib/test_helpers.js';

// Constants for testing
const TEST_ID = create_uuid();
const TEST_DATETIME = get_datetime_now();
const TEST_YEAR = 2022;

// Test suite variables
let app: Frontend;

beforeEach(() => {
	// Create a real Zzz instance for each test
	app = monkeypatch_zzz_for_tests(new Frontend());
	vi.clearAllMocks();
});

test('Cell uses registry for instantiating class relationships', () => {
	const Registry_Schema = Cell_Json.extend({
		text: z.string().default(''),
	});

	class Registry_Test_Cell extends Cell<typeof Registry_Schema> {
		text: string = $state()!;

		constructor(options: Cell_Options<typeof Registry_Schema>) {
			super(Registry_Schema, options);
			this.init();
		}

		test_instantiate(json: any, class_name: string): unknown {
			return this.app.cell_registry.instantiate(class_name as any, json);
		}
	}

	const cell = new Registry_Test_Cell({
		app,
		json: {
			id: TEST_ID,
			created: TEST_DATETIME,
		},
	});

	// Mock the registry instantiate method for this specific test
	const mock_instantiate = vi
		.spyOn(app.cell_registry, 'instantiate')
		.mockImplementation((name: any, json) => {
			if (name === 'Test_Type') {
				return {type: 'Test_Type', ...((json as any) || {})};
			}
			return null;
		});

	const test_object = {key: 'value'};
	const result = cell.test_instantiate(test_object, 'Test_Type');

	expect(mock_instantiate).toHaveBeenCalledWith('Test_Type', test_object);
	expect(result).toEqual({type: 'Test_Type', key: 'value'});

	// Clean up
	mock_instantiate.mockRestore();
});

test('Cell.encode_property uses $state.snapshot for values', () => {
	const Test_Schema = Cell_Json.extend({
		text: z.string().default(''),
	});

	class Encoding_Test_Cell extends Cell<typeof Test_Schema> {
		text: string = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);
			this.init();
		}

		test_encode(value: unknown, key: string): unknown {
			return this.encode_property(value, key);
		}
	}

	const cell = new Encoding_Test_Cell({
		app,
		json: {
			id: TEST_ID,
			created: TEST_DATETIME,
		},
	});

	// Test with Date object
	const test_date = new Date(`${TEST_YEAR}-01-15`);
	const encoded_date = cell.test_encode(test_date, 'date_field');
	expect(encoded_date instanceof Date).toBe(true);
	expect((encoded_date as Date).getFullYear()).toBe(TEST_YEAR);

	// Test with nested object
	const test_object = {outer: {inner: 42}};
	const encoded_object = cell.test_encode(test_object, 'object_field');
	expect(encoded_object).toEqual(test_object);
});

test('Cell handles special types like Map and Set', () => {
	const Collections_Schema = z.object({
		id: Uuid_With_Default,
		created: Datetime_Now,
		updated: z.string().nullable().default(null),
		// Test map collection
		map_field: z.preprocess(
			(val) => (Array.isArray(val) ? new Map(val as Array<[string, number]>) : val),
			z.map(z.string(), z.number()),
		),
		// Test set collection
		set_field: z.preprocess(
			(val) => (Array.isArray(val) ? new Set(val as Array<string>) : val),
			z.set(z.string()),
		),
	});

	class Collections_Test_Cell extends Cell<typeof Collections_Schema> {
		map_field: Map<string, number> = $state(new Map());
		set_field: Set<string> = $state(new Set());

		constructor(options: Cell_Options<typeof Collections_Schema>) {
			super(Collections_Schema, options);
			this.init();
		}

		test_decode<K extends Schema_Keys<typeof Collections_Schema>>(value: unknown, key: K): this[K] {
			return this.decode_property(value, key);
		}
	}

	const cell = new Collections_Test_Cell({
		app,
		json: {
			id: TEST_ID,
			created: TEST_DATETIME,
			map_field: [
				['key1', 1],
				['key2', 2],
			],
			set_field: ['item1', 'item2', 'item3'],
		},
	});

	// Verify Map handling
	expect(cell.map_field).toBeInstanceOf(Map);
	expect(cell.map_field.get('key1')).toBe(1);
	expect(cell.map_field.get('key2')).toBe(2);

	// Verify Set handling
	expect(cell.set_field).toBeInstanceOf(Set);
	expect(cell.set_field.has('item1')).toBe(true);
	expect(cell.set_field.has('item2')).toBe(true);
	expect(cell.set_field.has('item3')).toBe(true);

	// Test manual decoding
	const map_result = cell.test_decode([['key3', 3]], 'map_field');
	expect(map_result).toBeInstanceOf(Map);
	expect(map_result.get('key3')).toBe(3);

	const set_result = cell.test_decode(['item4', 'item5'], 'set_field');
	expect(set_result).toBeInstanceOf(Set);
	expect(set_result.has('item4')).toBe(true);
	expect(set_result.has('item5')).toBe(true);
});

test('Cell - JSON serialization excludes undefined values correctly', () => {
	const Serialization_Schema = Cell_Json.extend({
		type: z.enum(['type1', 'type2']),
		name: z.string().optional(),
		data: z
			.object({
				code: z.string().optional(),
				value: z.number().optional(),
			})
			.optional(),
		items: z.array(z.string()).optional(),
		state: z.enum(['on', 'off']).optional(),
	});

	class Serialization_Test_Cell extends Cell<typeof Serialization_Schema> {
		type: 'type1' | 'type2' = $state()!;
		name?: string = $state();
		data?: {code?: string; value?: number} = $state();
		items?: Array<string> = $state();
		state?: 'on' | 'off' = $state();

		constructor(options: Cell_Options<typeof Serialization_Schema>) {
			super(Serialization_Schema, options);
			this.init();
		}
	}

	// Cell with minimal required fields
	const minimal_cell = new Serialization_Test_Cell({
		app,
		json: {
			id: TEST_ID,
			created: TEST_DATETIME,
			type: 'type1',
		},
	});

	// Cell with optional fields
	const complete_cell = new Serialization_Test_Cell({
		app,
		json: {
			id: TEST_ID,
			created: TEST_DATETIME,
			type: 'type2',
			name: 'test_name',
			data: {code: 'test_code'},
			items: ['item1', 'item2'],
		},
	});

	// Test minimal cell serialization
	const minimal_json = minimal_cell.to_json();
	expect(minimal_json.type).toBe('type1');
	expect(minimal_json.name).toBeUndefined();
	expect(minimal_json.data).toBeUndefined();
	expect(minimal_json.items).toBeUndefined();
	expect(minimal_json.state).toBeUndefined();

	// Test complete cell serialization
	const complete_json = complete_cell.to_json();
	expect(complete_json.type).toBe('type2');
	expect(complete_json.name).toBe('test_name');
	expect(complete_json.data).toEqual({code: 'test_code'});
	expect(complete_json.data?.value).toBeUndefined();
	expect(complete_json.items).toEqual(['item1', 'item2']);
	expect(complete_json.state).toBeUndefined();

	// Test JSON stringification
	const minimal_string = JSON.stringify(minimal_cell);
	const parsed_minimal = JSON.parse(minimal_string);
	expect(parsed_minimal.name).toBeUndefined();
	expect(parsed_minimal.data).toBeUndefined();
	expect(parsed_minimal.items).toBeUndefined();
	expect(parsed_minimal.state).toBeUndefined();

	// Test nested property handling
	const complete_string = JSON.stringify(complete_cell);
	const parsed_complete = JSON.parse(complete_string);
	expect(parsed_complete.data.code).toBe('test_code');
	expect('value' in parsed_complete.data).toBe(false);
});
