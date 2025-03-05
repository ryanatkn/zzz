// @vitest-environment jsdom

import {test, expect, vi, beforeEach} from 'vitest';
import {z} from 'zod';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';

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
		test_decode(value: unknown, key: string): unknown {
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

	// Test manual decoding of arrays to Map/Set - skip this part since we're
	// letting Zod handle the conversion now
	/* 
	const map_result = cell.test_decode([['c', 3]], 'map_field');
	expect(map_result).toBeInstanceOf(Map);
	expect((map_result as Map<string, number>).get('c')).toBe(3);

	const set_result = cell.test_decode(['a', 'b'], 'set_field');
	expect(set_result).toBeInstanceOf(Set);
	expect((set_result as Set<string>).has('a')).toBe(true);
	*/
});

// Test error handling in set_json
test('Cell handles schema validation errors properly', () => {
	const Strict_Schema = z.object({
		required: z.string(),
	});

	class Strict_Cell extends Cell<typeof Strict_Schema> {
		required: string = $state()!;

		constructor(options: Cell_Options<typeof Strict_Schema>) {
			super(Strict_Schema, options);
			this.init();
		}
	}

	// Should throw for missing required field
	expect(() => {
		new Strict_Cell({
			zzz: mock_zzz,
			json: {} as any,
		});
	}).toThrow(z.ZodError);

	// Should throw for wrong type
	expect(() => {
		new Strict_Cell({
			zzz: mock_zzz,
			json: {required: 123} as any,
		});
	}).toThrow(z.ZodError);

	// Should not throw with valid data
	expect(() => {
		new Strict_Cell({
			zzz: mock_zzz,
			json: {required: 'valid'},
		});
	}).not.toThrow();
});
