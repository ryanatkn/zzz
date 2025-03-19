// @vitest-environment jsdom

import {test, expect, vi, beforeEach} from 'vitest';
import {z} from 'zod';
import {SvelteMap} from 'svelte/reactivity';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json, type Schema_Keys} from '$lib/cell_types.js';
import {Uuid, Datetime_Now} from '$lib/zod_helpers.js';
import {HANDLED, USE_DEFAULT} from '$lib/cell_helpers.js';

/* eslint-disable @typescript-eslint/dot-notation */

// Simple mock for Zzz
const create_mock_zzz = () => {
	return {
		cells: new SvelteMap<Uuid, Cell>(),
		registry: {
			instantiate: vi.fn((name, json) => {
				// For testing instantiation logic
				if (name === 'Test_Type' && json) {
					return {type: 'Test_Type', ...json};
				}
				return null;
			}),
			maybe_instantiate: vi.fn((name, json) => {
				// For testing instantiation logic
				if (name === 'Test_Type' && json) {
					return {type: 'Test_Type', ...json};
				}
				return null;
			}),
		},
	} as any;
};

// Reset mocks between tests
beforeEach(() => {
	vi.clearAllMocks();
});

// Test data constants
const TEST_ID = 'a0000000-0000-0000-0000-000000000001';
const TEST_DATE = new Date().toISOString();
const TEST_YEAR = 2022;

// Base test schema that extends Cell_Json
const Test_Schema = Cell_Json.extend({
	text: z.string().optional().default(''),
	number: z.number().optional(),
	list: z
		.array(z.string())
		.optional()
		.default(() => []),
	flag: z.boolean().default(true),
}).strict();

test('Cell uses registry for instantiating class relationships', () => {
	const mock_zzz = create_mock_zzz();

	class Registry_Test_Cell extends Cell<typeof Test_Schema> {
		text: string = $state()!;
		number: number | undefined = $state();
		list: Array<string> = $state()!;
		flag: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);
			this.init();
		}

		test_instantiate(json: any, class_name: string): unknown {
			return this.zzz.registry.instantiate(class_name as any, json);
		}
	}

	const cell = new Registry_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
		},
	});

	const test_object = {key: 'value'};
	const result = cell.test_instantiate(test_object, 'Test_Type');

	expect(mock_zzz.registry.instantiate).toHaveBeenCalledWith('Test_Type', test_object);
	expect(result).toEqual({type: 'Test_Type', key: 'value'});

	const null_result = cell.test_instantiate(test_object, 'Invalid_Type');
	expect(null_result).toBe(null);
});

test('Cell.encode_property uses $state.snapshot for values', () => {
	const mock_zzz = create_mock_zzz();

	class Encoding_Test_Cell extends Cell<typeof Test_Schema> {
		text: string = $state()!;
		number: number | undefined = $state();
		list: Array<string> = $state()!;
		flag: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);
			this.init();
		}

		test_encode(value: unknown, key: string): unknown {
			return this.encode_property(value, key);
		}
	}

	const cell = new Encoding_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
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
	const mock_zzz = create_mock_zzz();

	const Collections_Schema = z.object({
		id: Uuid,
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
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
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

test('Cell logs error when property does not exist on instance', () => {
	const mock_zzz = create_mock_zzz();
	const Missing_Property_Schema = Cell_Json.extend({
		existing_prop: z.string().default(''),
		missing_prop: z.number().default(42), // Won't exist on class
	});

	const console_error_spy = vi.spyOn(console, 'error');

	class Missing_Property_Cell extends Cell<typeof Missing_Property_Schema> {
		existing_prop: string = $state()!;
		// Missing 'missing_prop' property

		constructor(options: Cell_Options<typeof Missing_Property_Schema>) {
			super(Missing_Property_Schema, options);
			this.init();
		}
	}

	// eslint-disable-next-line no-new
	new Missing_Property_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
		},
	});

	expect(console_error_spy).toHaveBeenCalled();

	const error_message = `Schema key "missing_prop" in Missing_Property_Cell`;
	const found_error = console_error_spy.mock.calls.some((args) =>
		args.join(' ').includes(error_message),
	);
	expect(found_error).toBe(true);

	console_error_spy.mockRestore();
});

test('Cell allows schema keys with no properties if a decoder is provided', () => {
	const mock_zzz = create_mock_zzz();
	const Virtual_Property_Schema = Cell_Json.extend({
		real_prop: z.string().default(''),
		virtual_prop: z.number().default(42), // Won't exist on class
	});

	class Virtual_Property_Cell extends Cell<typeof Virtual_Property_Schema> {
		real_prop: string = $state()!;
		// No 'virtual_prop', will be handled by decoder

		captured_value = 0; // For verification

		constructor(options: Cell_Options<typeof Virtual_Property_Schema>) {
			super(Virtual_Property_Schema, options);

			this.decoders = {
				virtual_prop: (value) => {
					this.captured_value = typeof value === 'number' ? value : 0;
					return HANDLED;
				},
			};

			this.init();
		}
	}

	const cell = new Virtual_Property_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			virtual_prop: 99,
		},
	});

	expect(cell.captured_value).toBe(99);
});

test('Cell supports overriding assign_property', () => {
	const mock_zzz = create_mock_zzz();

	class Custom_Assignment_Cell extends Cell<typeof Test_Schema> {
		text: string = $state()!;
		number: number | undefined = $state();
		list: Array<string> = $state()!;
		flag: boolean = $state()!;

		assignment_log: Array<string> = [];

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);
			this.init();
		}

		protected override assign_property<K extends Schema_Keys<typeof Test_Schema>>(
			key: K,
			value: this[K],
		): void {
			this.assignment_log.push(`Assigned ${key}: ${String(value)}`);

			if (key === 'text' && typeof value === 'string') {
				super.assign_property(key, `modified_${value}` as any);
				return;
			}

			super.assign_property(key, value);
		}
	}

	const cell = new Custom_Assignment_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			text: 'original',
			list: ['item'],
		},
	});

	expect(cell.text).toBe('modified_original');
	expect(cell.assignment_log).toContain(`Assigned id: ${TEST_ID}`);
	expect(cell.assignment_log).toContain('Assigned text: original');
	expect(cell.assignment_log).toContain('Assigned list: item');
});

test('Cell supports virtual properties with custom handling', () => {
	const mock_zzz = create_mock_zzz();
	const Virtual_Handler_Schema = z.object({
		id: Uuid,
		created: Datetime_Now,
		updated: z.string().nullable().default(null),
		visible_prop: z.string(),
		hidden_prop: z.number().default(0),
	});

	class Virtual_Handler_Cell extends Cell<typeof Virtual_Handler_Schema> {
		visible_prop: string = $state()!;
		// No hidden_prop property

		processed_value = 0;

		constructor(options: Cell_Options<typeof Virtual_Handler_Schema>) {
			super(Virtual_Handler_Schema, options);

			this.decoders = {
				hidden_prop: (value) => {
					if (typeof value === 'number') {
						this.processed_value = value * 2;
					}
					return HANDLED; // Must return HANDLED for virtual properties
				},
			};

			this.init();
		}
	}

	const cell = new Virtual_Handler_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			visible_prop: 'visible',
			hidden_prop: 42,
		},
	});

	expect(cell.visible_prop).toBe('visible');
	expect('hidden_prop' in cell).toBe(false);
	expect(cell.processed_value).toBe(84); // 42 * 2
});

test('Cell assign_property returns after handling property correctly', () => {
	const mock_zzz = create_mock_zzz();

	class Return_Behavior_Cell extends Cell<typeof Test_Schema> {
		text: string = $state()!;
		number: number | undefined = $state();
		list: Array<string> = $state()!;
		flag: boolean = $state()!;

		execution_path: Array<string> = [];

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);
			this.init();
		}

		protected override assign_property<K extends Schema_Keys<typeof Test_Schema>>(
			key: K,
			value: this[K],
		): void {
			this.execution_path.push(`begin-${key}`);

			if (key === 'text') {
				super.assign_property(key, value);
				this.execution_path.push(`complete-${key}`);
				return;
			}

			this.execution_path.push(`continue-${key}`);
			super.assign_property(key, value);
		}
	}

	const cell = new Return_Behavior_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			text: 'sample',
			number: 42,
		},
	});

	expect(cell.text).toBe('sample');
	expect(cell.number).toBe(42);

	expect(cell.execution_path).toContain('begin-text');
	expect(cell.execution_path).toContain('complete-text');
	expect(cell.execution_path).not.toContain('continue-text');

	expect(cell.execution_path).toContain('begin-number');
	expect(cell.execution_path).toContain('continue-number');
});

test('Cell parser defaults take precedence over schema defaults', () => {
	const mock_zzz = create_mock_zzz();
	const Default_Precedence_Schema = z.object({
		id: z.string().default('schema_default_id'),
		created: Datetime_Now,
		updated: z.string().nullable().default(null),
		text: z.string().default('schema_default_text'),
	});

	class Default_Precedence_Cell extends Cell<typeof Default_Precedence_Schema> {
		text: string = $state()!;

		constructor(options: Cell_Options<typeof Default_Precedence_Schema>) {
			super(Default_Precedence_Schema, options);

			this.decoders = {
				id: (value) => {
					if (typeof value === 'string' && value !== 'schema_default_id') {
						return value as Uuid;
					}
					return 'parser_default_id' as Uuid;
				},
				// No decoder for text - schema default should be used
			};

			this.init();
		}
	}

	const cell = new Default_Precedence_Cell({
		zzz: mock_zzz,
		json: {},
	});

	expect(cell.id).toBe('parser_default_id');
	expect(cell.text).toBe('schema_default_text');
});

test('Cell handles inherited properties correctly', () => {
	const mock_zzz = create_mock_zzz();

	class Base_Test_Cell extends Cell<typeof Test_Schema> {
		text: string = $state()!;

		base_method() {
			return 'base_result';
		}

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);
			// Let derived class handle initialization
		}
	}

	class Derived_Test_Cell extends Base_Test_Cell {
		number: number | undefined = $state();
		list: Array<string> = $state()!;
		flag: boolean = $state()!;

		derived_method() {
			return 'derived_result';
		}

		override base_method() {
			return 'overridden_result';
		}

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(options);
			this.init();
		}
	}

	const cell = new Derived_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			text: 'base_property',
			number: 30,
			list: ['derived_item'],
			flag: true,
		},
	});

	expect(cell.id).toBe(TEST_ID);
	expect(cell.text).toBe('base_property');
	expect(cell.number).toBe(30);

	expect(cell.derived_method()).toBe('derived_result');
	expect(cell.base_method()).toBe('overridden_result');

	expect('id' in cell).toBe(true);

	const json = cell.json;
	expect(json.id).toBe(TEST_ID);
	expect(json.text).toBe('base_property');
	expect(json.number).toBe(30);
});

test('Cell - JSON serialization excludes undefined values correctly', () => {
	const mock_zzz = create_mock_zzz();
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
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			type: 'type1',
		},
	});

	// Cell with optional fields
	const complete_cell = new Serialization_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
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

test('Cell properly handles collections with HANDLED sentinel', () => {
	const mock_zzz = create_mock_zzz();
	const Virtual_Collection_Schema = Cell_Json.extend({
		collection: z.array(z.string()).default(() => []),
		text: z.string().default(''),
	});

	class Virtual_Collection_Cell extends Cell<typeof Virtual_Collection_Schema> {
		text: string = $state()!;
		// No direct collection property

		// Separately managed collection
		stored_items: Array<string> = [];

		constructor(options: Cell_Options<typeof Virtual_Collection_Schema>) {
			super(Virtual_Collection_Schema, options);

			this.decoders = {
				collection: (value) => {
					if (Array.isArray(value)) {
						this.stored_items = value.map((item) =>
							typeof item === 'string' ? item.toUpperCase() : String(item),
						);
					}
					return HANDLED;
				},
			};

			this.init();
		}

		override to_json(): z.output<typeof Virtual_Collection_Schema> {
			const base = super.to_json();
			return {
				...base,
				collection: this.stored_items,
			};
		}
	}

	const cell = new Virtual_Collection_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			collection: ['one', 'two', 'three'],
			text: 'sample',
		},
	});

	expect(cell.stored_items).toEqual(['ONE', 'TWO', 'THREE']);
	expect(cell.json.collection).toEqual(['ONE', 'TWO', 'THREE']);
});

test('Cell handles sentinel values with proper precedence', () => {
	const mock_zzz = create_mock_zzz();
	const Sentinel_Schema = Cell_Json.extend({
		handled_field: z.string().default(''),
		default_field: z.number().default(0),
		normal_field: z.boolean().default(false),
	});

	class Sentinel_Test_Cell extends Cell<typeof Sentinel_Schema> {
		handled_field: string = $state('initial_value');
		default_field: number = $state(-1);
		normal_field: boolean = $state()!;

		decoder_calls: Array<string> = [];

		constructor(options: Cell_Options<typeof Sentinel_Schema>) {
			super(Sentinel_Schema, options);

			this.decoders = {
				handled_field: (_value) => {
					this.decoder_calls.push('handled_field_called');
					// Short-circuit with HANDLED
					return HANDLED;
				},
				default_field: (_value) => {
					this.decoder_calls.push('default_field_called');
					// Fall through to default decoding
					return USE_DEFAULT;
				},
				normal_field: (_value) => {
					this.decoder_calls.push('normal_field_called');
					// Override with custom value
					return true;
				},
			};

			this.init();
		}
	}

	const cell = new Sentinel_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			handled_field: 'input_value',
			default_field: 42,
			normal_field: false,
		},
	});

	expect(cell.decoder_calls).toContain('handled_field_called');
	expect(cell.decoder_calls).toContain('default_field_called');
	expect(cell.decoder_calls).toContain('normal_field_called');

	expect(cell.handled_field).toBe('initial_value');
	expect(cell.default_field).toBe(42);
	expect(cell.normal_field).toBe(true);
});

test('Cell registration and unregistration works correctly', () => {
	const mock_zzz = create_mock_zzz();
	const cell_id = Uuid.parse(undefined);

	class Registration_Test_Cell extends Cell<typeof Test_Schema> {
		text: string = $state()!;
		number: number | undefined = $state();
		list: Array<string> = $state()!;
		flag: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);
			this.init();
		}
	}

	const cell = new Registration_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: cell_id,
			created: TEST_DATE,
		},
	});

	// Cell should be automatically registered
	expect(mock_zzz.cells.has(cell_id)).toBe(true);
	expect(mock_zzz.cells.get(cell_id)).toBe(cell);

	// Test manual unregistration
	cell['unregister']();
	expect(mock_zzz.cells.has(cell_id)).toBe(false);

	// Test manual registration again
	cell['register']();
	expect(mock_zzz.cells.has(cell_id)).toBe(true);

	// Test disposal
	cell['dispose']();
	expect(mock_zzz.cells.has(cell_id)).toBe(false);
});

test('Cell properly uses instantiate_class helper', () => {
	const mock_zzz = create_mock_zzz();

	class Instantiation_Test_Cell extends Cell<typeof Test_Schema> {
		text: string = $state()!;
		number: number | undefined = $state();
		list: Array<string> = $state()!;
		flag: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);
			this.init();
		}

		// Create a test method that replicates the functionality of #instantiate_class
		test_private_instantiate(class_name?: string, json?: unknown): any {
			if (!class_name) {
				console.error('No class name provided for instantiation');
				return null;
			}

			const instance = this.zzz.registry.maybe_instantiate(class_name as any, json);
			if (!instance) console.error(`Failed to instantiate ${class_name}`);
			return instance;
		}
	}

	const cell = new Instantiation_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
		},
	});

	// Should call registry.maybe_instantiate
	cell.test_private_instantiate('Test_Type', {test: true});
	expect(mock_zzz.registry.maybe_instantiate).toHaveBeenCalledWith('Test_Type', {test: true});

	// Should return null and log error for undefined class_name
	const console_error_spy = vi.spyOn(console, 'error');
	const result = cell.test_private_instantiate(undefined, {});
	expect(result).toBeNull();
	expect(console_error_spy).toHaveBeenCalled();
	console_error_spy.mockRestore();
});
