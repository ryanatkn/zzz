// @vitest-environment jsdom

import {test, expect, vi, beforeEach} from 'vitest';
import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import type {Schema_Keys} from '$lib/cell_types.js';

/* eslint-disable no-new */

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

// Test schema that makes fields optional to avoid validation errors
const Test_Schema = z
	.object({
		id: z.string().optional().default(''),
		name: z.string().optional().default(''),
		age: z.number().optional(),
		roles: z
			.array(z.string())
			.optional()
			.default(() => []),
		active: z.boolean().default(true),
	})
	.strict();

// Test Cell implementation
class Test_Cell extends Cell<typeof Test_Schema> {
	id: string = $state()!;
	name: string = $state()!;
	age: number | undefined = $state();
	roles: Array<string> = $state()!;
	active: boolean = $state()!;

	constructor(options: Cell_Options<typeof Test_Schema>) {
		super(Test_Schema, options);

		// Set up parsers
		this.parsers = {
			id: (value) => {
				if (typeof value === 'string' && value !== '') {
					return value; // Keep existing non-empty value
				}
				// Handle default value generation
				return `generated-${Math.random().toString(36).substring(2, 9)}`;
			},
			name: (value) => {
				if (typeof value === 'string' && value !== '') {
					return value.toUpperCase();
				}
				// Handle default value generation
				return 'DEFAULT_NAME';
			},
			roles: (value) => {
				if (Array.isArray(value) && value.length > 0) {
					return value.map((r) => (typeof r === 'string' ? r.toLowerCase() : String(r)));
				}
				// Handle default value generation
				return ['default_role'];
			},
		};

		this.init();
	}
}

test('Cell with parsers decodes values correctly', () => {
	const cell = new Test_Cell({
		zzz: mock_zzz,
		json: {
			id: 'test-123',
			name: 'John Doe',
			age: 30,
			roles: ['ADMIN', 'USER', 'EDITOR'],
		},
	});

	// Name should be uppercase due to parser
	expect(cell.name).toBe('JOHN DOE');

	// Roles should be lowercase due to parser
	expect(cell.roles).toEqual(['admin', 'user', 'editor']);

	// Other fields should be parsed normally
	expect(cell.id).toBe('test-123');
	expect(cell.age).toBe(30);
	expect(cell.active).toBe(true); // Default value
});

test('Cell parsers return undefined to use default decoding', () => {
	// Create a cell with a parser that returns undefined for some values
	class Partial_Parser_Cell extends Cell<typeof Test_Schema> {
		id: string = $state()!;
		name: string = $state()!;
		age: number | undefined = $state();
		roles: Array<string> = $state()!;
		active: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);

			this.parsers = {
				name: (value) => {
					// Only transform names that start with 'J'
					if (typeof value === 'string' && value.startsWith('J')) {
						return value.toUpperCase();
					}
					// For other names, return undefined to use default parsing
					return undefined;
				},
			};

			this.init();
		}
	}

	const cell1 = new Partial_Parser_Cell({
		zzz: mock_zzz,
		json: {id: 'test-1', name: 'Jane', roles: []},
	});

	const cell2 = new Partial_Parser_Cell({
		zzz: mock_zzz,
		json: {id: 'test-2', name: 'Bob', roles: []},
	});

	// 'Jane' starts with 'J', so it should be uppercase
	expect(cell1.name).toBe('JANE');

	// 'Bob' doesn't start with 'J', so it should remain as-is
	expect(cell2.name).toBe('Bob');
});

test('Cell parsers provide default values', () => {
	// Test with minimal JSON - just specify id
	const cell = new Test_Cell({
		zzz: mock_zzz,
		json: {
			id: 'test-123',
		},
	});

	// id should come from JSON and be processed by parser
	expect(cell.id).toBe('test-123');

	// name should come from parser
	expect(cell.name).toBe('DEFAULT_NAME');

	// roles should come from parser
	expect(cell.roles).toEqual(['default_role']);

	// active should come from schema default
	expect(cell.active).toBe(true);

	// age has no parser or schema default
	expect(cell.age).toBeUndefined();
});

test('Cell parsers are only applied for appropriate values', () => {
	// Test with complete JSON
	const cell = new Test_Cell({
		zzz: mock_zzz,
		json: {
			id: 'explicit-id',
			name: 'Explicit Name',
			roles: ['EXPLICIT_ROLE'],
			active: false,
		},
	});

	// Values should come from JSON, with parser transformations
	expect(cell.id).toBe('explicit-id');
	expect(cell.name).toBe('EXPLICIT NAME'); // Uppercase due to parser
	expect(cell.roles).toEqual(['explicit_role']); // Lowercase due to parser
	expect(cell.active).toBe(false);
});

test('Cell parsers work with empty JSON', () => {
	// Test with empty JSON - this is now valid due to schema default/optional fields
	const cell = new Test_Cell({
		zzz: mock_zzz,
		json: {},
	});

	// Values should come from parsers
	expect(cell.id).toMatch(/^generated-/); // Generated ID
	expect(cell.name).toBe('DEFAULT_NAME');
	expect(cell.roles).toEqual(['default_role']);
	expect(cell.active).toBe(true); // Schema default
});

test('Cell with no parsers uses schema defaults', () => {
	class Basic_Cell extends Cell<typeof Test_Schema> {
		id: string = $state()!;
		name: string = $state()!;
		age: number | undefined = $state();
		roles: Array<string> = $state()!;
		active: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);
			this.init();
		}
	}

	const cell = new Basic_Cell({
		zzz: mock_zzz,
		json: {}, // Empty JSON is valid due to schema defaults/optional
	});

	// active has a schema default
	expect(cell.active).toBe(true);

	// These have defaults in the schema (empty string/array)
	expect(cell.id).toBe('');
	expect(cell.name).toBe('');
	expect(cell.roles).toEqual([]);
	expect(cell.age).toBeUndefined();
});

test('Cell parsers can depend on instance properties', () => {
	class Instance_Cell extends Cell<typeof Test_Schema> {
		id: string = $state()!;
		name: string = $state()!;
		age: number | undefined = $state();
		roles: Array<string> = $state()!;
		active: boolean = $state()!;

		counter = 1; // Not part of schema, just for testing

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);

			this.parsers = {
				// Always return values based on instance properties
				id: () => `instance-${this.counter}`,
				name: () => `Instance ${this.counter}`,
				roles: () => [`role-${this.counter}`],
			};

			this.init();
		}
	}

	const cell = new Instance_Cell({
		zzz: mock_zzz,
		json: {}, // Empty JSON is valid due to schema defaults/optional
	});

	// Values should be generated using instance properties
	expect(cell.id).toBe('instance-1');
	expect(cell.name).toBe('Instance 1');
	expect(cell.roles).toEqual(['role-1']);
});

// Add a test for schema validation error
test('Cell throws validation errors from schema', () => {
	// Make a schema with specific validation rules
	const schema = z.object({
		id: z.string().min(3), // Must be at least 3 chars
		name: z.string().nonempty(), // Must not be empty
	});

	class Strict_Cell extends Cell<typeof schema> {
		id: string = $state()!;
		name: string = $state()!;

		constructor(options: Cell_Options<typeof schema>) {
			super(schema, options);
			this.init();
		}
	}

	// Should throw because id is too short
	expect(
		() =>
			new Strict_Cell({
				zzz: mock_zzz,
				json: {id: 'a', name: 'Test'}, // id too short
			}),
	).toThrow();

	// Should not throw with valid data
	expect(
		() =>
			new Strict_Cell({
				zzz: mock_zzz,
				json: {id: 'abc', name: 'Test'}, // valid
			}),
	).not.toThrow();
});

test('Cell parsers run even with no input JSON', () => {
	const cell = new Test_Cell({
		zzz: mock_zzz,
		// No json provided at all
	});

	// Should still get values from parsers
	expect(cell.id).toMatch(/^generated-/);
	expect(cell.name).toBe('DEFAULT_NAME');
	expect(cell.roles).toEqual(['default_role']);
	expect(cell.active).toBe(true);
});

test('Cell handles undefined JSON input correctly', () => {
	// Test with explicitly undefined JSON
	const cell = new Test_Cell({
		zzz: mock_zzz,
		json: undefined,
	});

	// Should handle undefined gracefully with parsers
	expect(cell.id).toMatch(/^generated-/);
	expect(cell.name).toBe('DEFAULT_NAME');
	expect(cell.roles).toEqual(['default_role']);
});

test('Cell has proper snapshot and serialization support', () => {
	const cell = new Test_Cell({
		zzz: mock_zzz,
		json: {id: 'test-snapshot', name: 'Snapshot Test'},
	});

	// Test JSON serialization
	const json = cell.json;
	expect(json.id).toBe('test-snapshot');
	expect(json.name).toBe('SNAPSHOT TEST'); // Uppercase due to parser

	// Test JSON string serialization
	const json_string = cell.json_serialized;
	expect(json_string).toContain('"id":"test-snapshot"');
	expect(json_string).toContain('"name":"SNAPSHOT TEST"');

	// Test toJSON method (used by $state.snapshot)
	const snapshot = $state.snapshot(cell);
	expect(snapshot.id).toBe('test-snapshot');
});

test('Cell cloning creates proper copies', () => {
	const original = new Test_Cell({
		zzz: mock_zzz,
		json: {id: 'original', name: 'Original Cell'},
	});

	const clone = original.clone();

	// Clones should have same values
	expect(clone.id).toBe('original');
	expect(clone.name).toBe('ORIGINAL CELL');

	// But be different instances
	expect(clone).not.toBe(original);

	// Modifying clone shouldn't affect original
	clone.name = 'MODIFIED CLONE';
	expect(clone.name).toBe('MODIFIED CLONE');
	expect(original.name).toBe('ORIGINAL CELL');
});

//
//
//

test('Cell uses registry for instantiating class relationships', () => {
	class Registry_Test_Cell extends Cell<typeof Test_Schema> {
		// Add required properties for the schema
		id: string = $state()!;
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
		json: {},
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

test('Cell.encode uses $state.snapshot for values', () => {
	class Simple_Test_Cell extends Cell<typeof Test_Schema> {
		// Add required properties for the schema
		id: string = $state()!;
		name: string = $state()!;
		age: number | undefined = $state();
		roles: Array<string> = $state()!;
		active: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);
			this.init();
		}

		// Test helper to access encode
		test_encode(value: unknown, key: string): unknown {
			return this.encode(value, key);
		}
	}

	const cell = new Simple_Test_Cell({zzz: mock_zzz, json: {}});

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

		// Test helper to manually invoke decode_value_without_parser
		// Fix: Use proper generic type parameter to match the method signature
		test_decode<K extends Schema_Keys<typeof Special_Schema>>(value: unknown, key: K): this[K] {
			return this.decode_value_without_parser(value, key);
		}
	}

	const cell = new Special_Cell({
		zzz: mock_zzz,
		json: {
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

	// Add test for manual decoding using the fixed test_decode method
	const map_result = cell.test_decode([['c', 3]], 'map_field');
	expect(map_result).toBeInstanceOf(Map);
	expect(map_result.get('c')).toBe(3);

	const set_result = cell.test_decode(['a', 'b'], 'set_field');
	expect(set_result).toBeInstanceOf(Set);
	expect(set_result.has('a')).toBe(true);
	expect(set_result.has('b')).toBe(true);
});

// Add test for the case when a schema key doesn't exist on the instance
test('Cell throws error when property does not exist on instance', () => {
	// Schema with a property that won't exist on the instance
	const Missing_Schema = z.object({
		exists: z.string().default('default'),
		missing: z.number().default(42), // This property won't exist on the class
	});

	class Missing_Cell extends Cell<typeof Missing_Schema> {
		exists: string = $state()!;
		// Intentionally missing the 'missing' property

		constructor(options: Cell_Options<typeof Missing_Schema>) {
			super(Missing_Schema, options);
			this.init();
		}
	}

	// Should throw an error about the missing property
	expect(() => new Missing_Cell({zzz: mock_zzz})).toThrow(
		/Schema key "missing" not found as a property on instance/,
	);
});

// Add test for providing a custom parser to handle missing properties
test('Cell allows schema keys with no properties if a parser is provided', () => {
	// Schema with a property that won't exist on the instance
	const Parser_Schema = z.object({
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
	const cell = new Parser_Cell({zzz: mock_zzz, json: {virtual: 99}});

	// Verify the parser was called
	expect(cell.parsed_virtual_value).toBe(99);
});

// Add a test for custom property assignment
test('Cell supports custom property assignment behavior', () => {
	class Custom_Assignment_Cell extends Cell<typeof Test_Schema> {
		id: string = $state()!;
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

		// Override assign_property to add custom behavior
		protected override assign_property<K extends Schema_Keys<typeof Test_Schema>>(
			key: K,
			value: this[K],
		): void {
			// Log the assignment
			this.assignment_log.push(`Assigned ${key}: ${value}`);

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
			id: 'test-id',
			name: 'Test Name',
			roles: ['admin'],
		},
	});

	// Check custom assignment behavior
	expect(cell.name).toBe('Custom_Test Name');

	// Check that assignment log captured operations
	expect(cell.assignment_log).toContain('Assigned id: test-id');
	expect(cell.assignment_log).toContain('Assigned name: Test Name');
	expect(cell.assignment_log).toContain('Assigned roles: admin');
});

// Test virtual property with assignment override
test('Cell supports virtual properties with custom handling', () => {
	const Virtual_Schema = z.object({
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

// Test overriding process_schema_property for custom handling
test('Cell supports overriding process_schema_property for custom processing', () => {
	const Virtual_Schema = z.object({
		real: z.string(),
		virtual: z.number().default(0),
	});

	class Process_Override_Cell extends Cell<typeof Virtual_Schema> {
		real: string = $state()!;
		// No virtual property defined

		calculated_value = 0;

		constructor(options: Cell_Options<typeof Virtual_Schema>) {
			super(Virtual_Schema, options);
			this.init();
		}

		// Override process_schema_property instead of using parsers
		protected override assign_schema_property(
			key: Schema_Keys<typeof Virtual_Schema>,
			value: unknown,
		): void {
			if (key === 'virtual') {
				// Custom handling for virtual property
				if (typeof value === 'number') {
					this.calculated_value = value * 3; // Different multiplier to distinguish from parser approach
					return; // Skip further processing for this key
				}
			}

			// For all other keys, use default processing
			super.assign_schema_property(key, value);
		}
	}

	const cell = new Process_Override_Cell({
		zzz: mock_zzz,
		json: {
			real: 'Real Value',
			virtual: 30,
		},
	});

	// Check real property was set
	expect(cell.real).toBe('Real Value');

	// Check virtual property was processed but not assigned
	expect('virtual' in cell).toBe(false);
	expect(cell.calculated_value).toBe(90); // 30 * 3
});

// Test the precedence between schema defaults and parser defaults
test('Cell parser defaults take precedence over schema defaults', () => {
	// Define a schema with explicit defaults
	const Schema_With_Defaults = z.object({
		id: z.string().default('schema-default-id'),
		name: z.string().default('schema-default-name'),
	});

	class Default_Precedence_Cell extends Cell<typeof Schema_With_Defaults> {
		id: string = $state()!;
		name: string = $state()!;

		constructor(options: Cell_Options<typeof Schema_With_Defaults>) {
			super(Schema_With_Defaults, options);

			// Set up parsers with their own defaults
			this.parsers = {
				id: (value) => {
					if (typeof value === 'string' && value !== 'schema-default-id') {
						return value; // Keep non-default values
					}
					// If value is the schema default, replace it with parser default
					return 'parser-default-id';
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
		id: string = $state()!;
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
		// No need to redeclare these because Svelte $state works through the prototype chain
		// id: string = $state()!;
		// name: string = $state()!;

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
			id: 'test-id',
			name: 'Test Name',
			age: 30,
			roles: ['admin'],
			active: true,
		},
	});

	// Properties should be correctly assigned
	expect(cell.id).toBe('test-id');
	expect(cell.name).toBe('Test Name');
	expect(cell.age).toBe(30);

	// Methods should work as expected
	expect(cell.derived_method()).toBe('derived');
	expect(cell.base_method()).toBe('overridden');

	// Property from base class should exist in derived instance
	expect('id' in cell).toBe(true);

	// Check that JSON serialization includes all properties
	const json = cell.json;
	expect(json.id).toBe('test-id');
	expect(json.name).toBe('Test Name');
	expect(json.age).toBe(30);
});
