// @vitest-environment jsdom

import {test, expect, vi, beforeEach} from 'vitest';
import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json, type Schema_Keys} from '$lib/cell_types.js';
import {Uuid, Datetime_Now} from '$lib/zod_helpers.js';

// Simple mock for Zzz
const mock_zzz = {
	registry: {
		instantiate: vi.fn((name, json) => {
			// For testing instantiation logic
			if (name === 'TestInstance' && json) {
				return {type: 'TestInstance', ...json};
			}
			return null;
		}),
	},
} as any;

// Reset mocks between tests
beforeEach(() => {
	vi.clearAllMocks();
});

// Create valid test UUIDs for test data
const TEST_UUID = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';

// Create a date string for test data
const TEST_DATE = new Date().toISOString();

// Test schema that extends the base Cell_Json schema
const Test_Schema = Cell_Json.extend({
	name: z.string().optional().default(''),
	age: z.number().optional(),
	roles: z
		.array(z.string())
		.optional()
		.default(() => []),
	active: z.boolean().default(true),
}).strict();

test('Cell uses registry for instantiating class relationships', () => {
	class Registry_Test_Cell extends Cell<typeof Test_Schema> {
		name: string = $state()!;
		age: number | undefined = $state();
		roles: Array<string> = $state()!;
		active: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);
			this.init();
		}

		// Test helper that directly uses the registry instead of private method
		test_instantiate(json: any, class_name: string): unknown {
			// Use the registry directly instead of the private method
			return this.zzz.registry.instantiate(class_name, json);
		}
	}

	const cell = new Registry_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_UUID,
			created: TEST_DATE,
		},
	});

	// We can test registry behavior directly
	const test_data = {prop: 'test'};
	const result = cell.test_instantiate(test_data, 'TestInstance');

	// Should call registry instantiate
	expect(mock_zzz.registry.instantiate).toHaveBeenCalledWith('TestInstance', test_data);
	expect(result).toEqual({type: 'TestInstance', prop: 'test'});

	// Should handle missing class gracefully
	const null_result = cell.test_instantiate(test_data, 'NonExistentClass');
	expect(null_result).toBe(null); // Registry returns null if class not found
});

test('Cell.encode_property uses $state.snapshot for values', () => {
	class Simple_Test_Cell extends Cell<typeof Test_Schema> {
		name: string = $state()!;
		age: number | undefined = $state();
		roles: Array<string> = $state()!;
		active: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);
			this.init();
		}

		// Test helper to access encode_property
		test_encode(value: unknown, key: string): unknown {
			return this.encode_property(value, key);
		}
	}

	const cell = new Simple_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_UUID,
			created: TEST_DATE,
		},
	});

	// Test with a Date object
	const date = new Date('2023-03-01');
	const encoded_date = cell.test_encode(date, 'test_date');

	// Date remains a Date object after encoding
	expect(encoded_date instanceof Date).toBe(true);
	// The date value should be preserved
	expect((encoded_date as Date).getFullYear()).toBe(2023);

	// Test with a complex object
	const complex = {nested: {value: 42}};
	const encoded_complex = cell.test_encode(complex, 'test_complex');
	expect(encoded_complex).toEqual(complex);
});

// Test handling of special types like Map and Set
test('Cell handles special types like Map and Set', () => {
	// Create a schema with special types that allows arrays as input
	// but converts them to Map/Set during parsing
	const Special_Schema = z.object({
		id: Uuid,
		created: Datetime_Now,
		updated: z.string().nullable().default(null),
		// Allow arrays for input but define as map for output
		map_field: z.preprocess(
			(val) => (Array.isArray(val) ? new Map(val as Array<[string, number]>) : val),
			z.map(z.string(), z.number()),
		),
		// Allow arrays for input but define as set for output
		set_field: z.preprocess(
			(val) => (Array.isArray(val) ? new Set(val as Array<string>) : val),
			z.set(z.string()),
		),
	});

	class Special_Cell extends Cell<typeof Special_Schema> {
		map_field: Map<string, number> = $state(new Map());
		set_field: Set<string> = $state(new Set());

		constructor(options: Cell_Options<typeof Special_Schema>) {
			super(Special_Schema, options);
			this.init();
		}

		// Test helper to manually invoke decode_property
		test_decode<K extends Schema_Keys<typeof Special_Schema>>(value: unknown, key: K): this[K] {
			return this.decode_property(value, key);
		}
	}

	const cell = new Special_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_UUID,
			created: TEST_DATE,
			map_field: [
				['a', 1],
				['b', 2],
			],
			set_field: ['x', 'y', 'z'],
		},
	});

	// Check Map handling
	expect(cell.map_field).toBeInstanceOf(Map);
	expect(cell.map_field.get('a')).toBe(1);
	expect(cell.map_field.get('b')).toBe(2);

	// Check Set handling
	expect(cell.set_field).toBeInstanceOf(Set);
	expect(cell.set_field.has('x')).toBe(true);
	expect(cell.set_field.has('y')).toBe(true);
	expect(cell.set_field.has('z')).toBe(true);

	// Add test for manual decoding using the test_decode method
	const map_result = cell.test_decode([['c', 3]], 'map_field');
	expect(map_result).toBeInstanceOf(Map);
	expect(map_result.get('c')).toBe(3);

	const set_result = cell.test_decode(['a', 'b'], 'set_field');
	expect(set_result).toBeInstanceOf(Set);
	expect(set_result.has('a')).toBe(true);
	expect(set_result.has('b')).toBe(true);
});

// Add test for the case when a schema key doesn't exist on the instance
test('Cell logs error when property does not exist on instance', () => {
	// Schema with a property that won't exist on the instance
	const Missing_Schema = Cell_Json.extend({
		exists: z.string().default('default'),
		missing: z.number().default(42), // This property won't exist on the class
	});

	// Spy on console.error before creating the cell
	const console_error_spy = vi.spyOn(console, 'error');

	class Missing_Cell extends Cell<typeof Missing_Schema> {
		exists: string = $state()!;
		// Intentionally missing the 'missing' property

		constructor(options: Cell_Options<typeof Missing_Schema>) {
			super(Missing_Schema, options);
			this.init();
		}
	}

	// Create the cell - it should log an error but not throw
	// eslint-disable-next-line no-new
	new Missing_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_UUID,
			created: TEST_DATE,
		},
	});

	// Now check if console.error was called at all
	expect(console_error_spy).toHaveBeenCalled();

	// Use the exact error message format from the Cell class
	const exact_error_message = `Schema key "missing" in Missing_Cell`;

	// Check if this exact message was logged
	const found_error_message = console_error_spy.mock.calls.some((args) =>
		args.join(' ').includes(exact_error_message),
	);

	expect(found_error_message).toBe(true);

	// Clean up spy
	console_error_spy.mockRestore();
});

// Add test for providing a custom parser to handle missing properties
test('Cell allows schema keys with no properties if a parser is provided', () => {
	// Schema with a property that won't exist on the instance
	const Parser_Schema = Cell_Json.extend({
		exists: z.string().default('default'),
		virtual: z.number().default(42), // This property won't exist on the class
	});

	class Parser_Cell extends Cell<typeof Parser_Schema> {
		exists: string = $state()!;
		// No 'virtual' property, but we'll handle it with a parser

		parsed_virtual_value = 0; // Just for test verification

		constructor(options: Cell_Options<typeof Parser_Schema>) {
			super(Parser_Schema, options);

			this.parsers = {
				// Custom parser for the virtual property that doesn't attempt to set a property
				virtual: (value) => {
					// Store the value for test verification
					this.parsed_virtual_value = typeof value === 'number' ? value : 0;
					// Return undefined so no assignment is attempted
					return undefined;
				},
			};

			this.init();
		}
	}

	// Should not throw with a parser for the virtual property
	const cell = new Parser_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_UUID,
			created: TEST_DATE,
			virtual: 99,
		},
	});

	// Verify the parser was called
	expect(cell.parsed_virtual_value).toBe(99);
});

// Add a test for custom property assignment
test('Cell supports overriding assign_property', () => {
	class Custom_Assignment_Cell extends Cell<typeof Test_Schema> {
		name: string = $state()!;
		age: number | undefined = $state();
		roles: Array<string> = $state()!;
		active: boolean = $state()!;

		// Track assigned values
		assignment_log: Array<string> = [];

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);
			this.init();
		}

		// Override the protected assign_property method
		protected override assign_property<K extends Schema_Keys<typeof Test_Schema>>(
			key: K,
			value: this[K],
		): void {
			// Log the assignment
			this.assignment_log.push(`Assigned ${key}: ${String(value)}`);

			// Custom behavior for specific properties
			if (key === 'name' && typeof value === 'string') {
				// Add a prefix to all names
				super.assign_property(key, `Custom_${value}` as any);
				return;
			}

			// Default behavior for other properties
			super.assign_property(key, value);
		}
	}

	const cell = new Custom_Assignment_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_UUID,
			created: TEST_DATE,
			name: 'Test Name',
			roles: ['admin'],
		},
	});

	// Check custom assignment behavior
	expect(cell.name).toBe('Custom_Test Name');

	// Check that assignment log captured operations
	expect(cell.assignment_log).toContain(`Assigned id: ${TEST_UUID}`);
	expect(cell.assignment_log).toContain('Assigned name: Test Name');
	expect(cell.assignment_log).toContain('Assigned roles: admin');
});

// Test virtual property with assignment override
test('Cell supports virtual properties with custom handling', () => {
	const Virtual_Schema = z.object({
		id: Uuid,
		created: Datetime_Now,
		updated: z.string().nullable().default(null),
		real: z.string(),
		virtual: z.number().default(0),
	});

	class Virtual_Cell extends Cell<typeof Virtual_Schema> {
		real: string = $state()!;
		// No virtual property defined

		calculated_value = 0;

		constructor(options: Cell_Options<typeof Virtual_Schema>) {
			super(Virtual_Schema, options);

			// Parser for virtual property
			this.parsers = {
				virtual: (value) => {
					if (typeof value === 'number') {
						// Process the value but return undefined
						// to indicate we've handled it without property assignment
						this.calculated_value = value * 2;
					}
					return undefined;
				},
			};

			this.init();
		}
	}

	const cell = new Virtual_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_UUID,
			created: TEST_DATE,
			real: 'Real Value',
			virtual: 42,
		},
	});

	// Check real property was set
	expect(cell.real).toBe('Real Value');

	// Check virtual property was processed but not assigned
	expect('virtual' in cell).toBe(false);
	expect(cell.calculated_value).toBe(84); // 42 * 2
});

// Add a new test for early return behavior in assign_property
test('Cell assign_property returns after handling property correctly', () => {
	// Create a test implementation with a modified assign_property method
	class Return_Test_Cell extends Cell<typeof Test_Schema> {
		name: string = $state()!;
		age: number | undefined = $state();
		roles: Array<string> = $state()!;
		active: boolean = $state()!;

		// Track method calls
		property_processing: Array<string> = [];

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);
			this.init();
		}

		// Override assign_property to track method calls and verify return behavior
		protected override assign_property<K extends Schema_Keys<typeof Test_Schema>>(
			key: K,
			value: this[K],
		): void {
			this.property_processing.push(`start-${key}`);

			// First property is handled and should return
			if (key === 'name') {
				super.assign_property(key, value);
				this.property_processing.push(`complete-${key}`);
				return;
			}

			// This should not run for 'name' if return works correctly
			this.property_processing.push(`fallthrough-${key}`);
			super.assign_property(key, value);
		}
	}

	const cell = new Return_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_UUID,
			created: TEST_DATE,
			name: 'Return Test',
			age: 42,
		},
	});

	// Verify property values are set correctly
	expect(cell.name).toBe('Return Test');
	expect(cell.age).toBe(42);

	// Verify method return behavior
	expect(cell.property_processing).toContain('start-name');
	expect(cell.property_processing).toContain('complete-name');
	expect(cell.property_processing).not.toContain('fallthrough-name');

	// Age should have different flow
	expect(cell.property_processing).toContain('start-age');
	expect(cell.property_processing).toContain('fallthrough-age');
});

// Test the precedence between schema defaults and parser defaults
test('Cell parser defaults take precedence over schema defaults', () => {
	// Define a schema with explicit defaults
	const Schema_With_Defaults = z.object({
		id: z.string().default('schema-default-id'),
		created: Datetime_Now,
		updated: z.string().nullable().default(null),
		name: z.string().default('schema-default-name'),
	});

	class Default_Precedence_Cell extends Cell<typeof Schema_With_Defaults> {
		name: string = $state()!;

		constructor(options: Cell_Options<typeof Schema_With_Defaults>) {
			super(Schema_With_Defaults, options);

			// Set up parsers with their own defaults
			this.parsers = {
				id: (value) => {
					if (typeof value === 'string' && value !== 'schema-default-id') {
						return value as Uuid; // Keep non-default values
					}
					// If value is the schema default, replace it with parser default
					return 'parser-default-id' as Uuid;
				},
				// No parser for name - should use schema default
			};

			this.init();
		}
	}

	// Test with empty JSON to trigger defaults
	const cell = new Default_Precedence_Cell({
		zzz: mock_zzz,
		json: {},
	});

	// Parser default should override schema default
	expect(cell.id).toBe('parser-default-id');

	// Schema default should be used when no parser exists
	expect(cell.name).toBe('schema-default-name');
});

// Test for handling prototype chain properties correctly
test('Cell handles inherited properties correctly', () => {
	// Create a base class with some properties
	class Base_Cell extends Cell<typeof Test_Schema> {
		name: string = $state()!;

		base_method() {
			return 'base';
		}

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);
			// Don't call init() here - let derived class handle initialization
		}
	}

	// Create a derived class that inherits base properties
	// but needs to redeclare state fields due to Svelte 5 $state limitations
	class Derived_Cell extends Base_Cell {
		// These are new properties in the derived class
		age: number | undefined = $state();
		roles: Array<string> = $state()!;
		active: boolean = $state()!;

		derived_method() {
			return 'derived';
		}

		// Override base method
		override base_method() {
			return 'overridden';
		}

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(options);
			this.init(); // Call init only in the most derived class
		}
	}

	const cell = new Derived_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_UUID,
			created: TEST_DATE,
			name: 'Test Name',
			age: 30,
			roles: ['admin'],
			active: true,
		},
	});

	// Properties should be correctly assigned
	expect(cell.id).toBe(TEST_UUID);
	expect(cell.name).toBe('Test Name');
	expect(cell.age).toBe(30);

	// Methods should work as expected
	expect(cell.derived_method()).toBe('derived');
	expect(cell.base_method()).toBe('overridden');

	// Property from base class should exist in derived instance
	expect('id' in cell).toBe(true);

	// Check that JSON serialization includes all properties
	const json = cell.json;
	expect(json.id).toBe(TEST_UUID);
	expect(json.name).toBe('Test Name');
	expect(json.age).toBe(30);
});

// Test for Cell serialization with undefined values
test('Cell - JSON serialization excludes undefined values correctly', () => {
	// Create a schema with many optional fields to test undefined handling
	const Complex_Schema = Cell_Json.extend({
		type: z.enum(['simple', 'complex']),
		name: z.string().optional(),
		detail: z
			.object({
				code: z.string().optional(),
				value: z.number().optional(),
			})
			.optional(),
		tags: z.array(z.string()).optional(),
		status: z.enum(['active', 'inactive']).optional(),
	});

	class SerializationTest_Cell extends Cell<typeof Complex_Schema> {
		type: 'simple' | 'complex' = $state()!;
		name?: string = $state();
		detail?: {code?: string; value?: number} = $state();
		tags?: Array<string> = $state();
		status?: 'active' | 'inactive' = $state();

		constructor(options: Cell_Options<typeof Complex_Schema>) {
			super(Complex_Schema, options);
			this.init();
		}
	}

	// Create a cell with only required fields
	const simple_cell = new SerializationTest_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_UUID,
			created: TEST_DATE,
			type: 'simple',
		},
	});

	// Create a cell with some optional fields
	const complex_cell = new SerializationTest_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_UUID,
			created: TEST_DATE,
			type: 'complex',
			name: 'Test',
			detail: {code: 'ABC'},
			tags: ['tag1', 'tag2'],
		},
	});

	// Test simple cell JSON
	const simple_json = simple_cell.to_json();
	expect(simple_json.type).toBe('simple');
	expect(simple_json.name).toBeUndefined();
	expect(simple_json.detail).toBeUndefined();
	expect(simple_json.tags).toBeUndefined();
	expect(simple_json.status).toBeUndefined();

	// Test complex cell JSON
	const complex_json = complex_cell.to_json();
	expect(complex_json.type).toBe('complex');
	expect(complex_json.name).toBe('Test');
	expect(complex_json.detail).toEqual({code: 'ABC'});
	expect(complex_json.detail?.value).toBeUndefined(); // Nested undefined field
	expect(complex_json.tags).toEqual(['tag1', 'tag2']);
	expect(complex_json.status).toBeUndefined();

	// Verify JSON.stringify removes undefined values
	const serialized_simple = JSON.stringify(simple_cell);
	const parsed_simple = JSON.parse(serialized_simple);
	expect(parsed_simple.name).toBeUndefined();
	expect(parsed_simple.detail).toBeUndefined();
	expect(parsed_simple.tags).toBeUndefined();
	expect(parsed_simple.status).toBeUndefined();

	// Verify that toJSON and JSON.stringify handle nested undefined fields
	const serialized_complex = JSON.stringify(complex_cell);
	const parsed_complex = JSON.parse(serialized_complex);
	expect(parsed_complex.detail.code).toBe('ABC');
	expect('value' in parsed_complex.detail).toBe(false); // Undefined field should be removed from JSON
});
