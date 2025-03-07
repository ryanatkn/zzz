// @vitest-environment jsdom

import {test, expect, vi, beforeEach} from 'vitest';
import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
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
const SECOND_UUID = 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22';

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

// Test Cell implementation
class Test_Cell extends Cell<typeof Test_Schema> {
	name: string = $state()!;
	age: number | undefined = $state();
	roles: Array<string> = $state()!;
	active: boolean = $state()!;

	constructor(options: Cell_Options<typeof Test_Schema>) {
		super(Test_Schema, options);

		// Set up parsers
		this.parsers = {
			id: (value) => {
				if (typeof value === 'string' && value.length > 0) {
					return value as Uuid; // Keep existing non-empty value
				}
				// Handle default value generation
				return `generated-${Math.random().toString(36).substring(2, 9)}` as Uuid;
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
			id: TEST_UUID,
			created: TEST_DATE,
			updated: null,
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
	expect(cell.id).toBe(TEST_UUID);
	expect(cell.age).toBe(30);
	expect(cell.active).toBe(true); // Default value
});

test('Cell parsers return undefined to use default decoding', () => {
	// Create a cell with a parser that returns undefined for some values
	class Partial_Parser_Cell extends Cell<typeof Test_Schema> {
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
		json: {
			id: TEST_UUID,
			created: TEST_DATE,
			name: 'Jane',
			roles: [],
		},
	});

	const cell2 = new Partial_Parser_Cell({
		zzz: mock_zzz,
		json: {
			id: SECOND_UUID,
			created: TEST_DATE,
			name: 'Bob',
			roles: [],
		},
	});

	// 'Jane' starts with 'J', so it should be uppercase
	expect(cell1.name).toBe('JANE');

	// 'Bob' doesn't start with 'J', so it should remain as-is
	expect(cell2.name).toBe('Bob');
});

test('Cell parsers provide default values', () => {
	// Test with minimal JSON - just specify required fields
	const cell = new Test_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_UUID,
			created: TEST_DATE,
		},
	});

	// id should come from JSON and be processed by parser
	expect(cell.id).toBe(TEST_UUID);

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
			id: TEST_UUID,
			created: TEST_DATE,
			name: 'Explicit Name',
			roles: ['EXPLICIT_ROLE'],
			active: false,
		},
	});

	// Values should come from JSON, with parser transformations
	expect(cell.id).toBe(TEST_UUID);
	expect(cell.name).toBe('EXPLICIT NAME'); // Uppercase due to parser
	expect(cell.roles).toEqual(['explicit_role']); // Lowercase due to parser
	expect(cell.active).toBe(false);
});

test('Cell parsers work with empty JSON', () => {
	// Create a modified test cell specifically for this test
	class EmptyJsonTestCell extends Cell<typeof Test_Schema> {
		name: string = $state()!;
		age: number | undefined = $state();
		roles: Array<string> = $state()!;
		active: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);

			// Ensure id parser always returns a generated id pattern for this test
			this.parsers = {
				id: () => `generated-${Math.random().toString(36).substring(2, 9)}` as Uuid,
				name: () => 'DEFAULT_NAME',
				roles: () => ['default_role'],
			};

			this.init();
		}
	}

	// Test with empty JSON - this is now valid due to schema default/optional fields
	const cell = new EmptyJsonTestCell({
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
	// Create a custom test schema with string ID for easier testing
	const BasicTestSchema = z
		.object({
			id: z.string().default(''),
			created: z
				.string()
				.datetime()
				.default(() => new Date().toISOString()),
			updated: z.string().nullable().default(null),
			name: z.string().default(''),
			age: z.number().optional(),
			roles: z.array(z.string()).default(() => []),
			active: z.boolean().default(true),
		})
		.strict();

	class Basic_Cell extends Cell<typeof BasicTestSchema> {
		name: string = $state()!;
		age: number | undefined = $state();
		roles: Array<string> = $state()!;
		active: boolean = $state()!;

		constructor(options: Cell_Options<typeof BasicTestSchema>) {
			super(BasicTestSchema, options);
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
		name: string = $state()!;
		age: number | undefined = $state();
		roles: Array<string> = $state()!;
		active: boolean = $state()!;

		counter = 1; // Not part of schema, just for testing

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);

			this.parsers = {
				// Always return values based on instance properties
				id: () => `instance-${this.counter}` as Uuid,
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

test('Cell throws validation errors from schema', () => {
	// Make a schema with specific validation rules
	const schema = z.object({
		id: Uuid,
		created: Datetime_Now,
		updated: z.string().nullable().default(null),
		name: z.string().nonempty(), // Must not be empty
	});

	class Strict_Cell extends Cell<typeof schema> {
		name: string = $state()!;

		constructor(options: Cell_Options<typeof schema>) {
			super(schema, options);
			this.init();
		}
	}

	// Should throw because name is empty
	expect(
		() =>
			new Strict_Cell({
				zzz: mock_zzz,
				json: {
					id: TEST_UUID,
					created: TEST_DATE,
					name: '', // Empty name, should fail
				},
			}),
	).toThrow();

	// Should not throw with valid data
	expect(
		() =>
			new Strict_Cell({
				zzz: mock_zzz,
				json: {
					id: TEST_UUID,
					created: TEST_DATE,
					name: 'Test', // Valid name
				},
			}),
	).not.toThrow();
});

test('Cell parsers run even with no input JSON', () => {
	// Create a modified test cell specifically for this test
	class NoInputJsonTestCell extends Cell<typeof Test_Schema> {
		name: string = $state()!;
		age: number | undefined = $state();
		roles: Array<string> = $state()!;
		active: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);

			// Ensure id parser always returns a generated id pattern for this test
			this.parsers = {
				id: () => `generated-${Math.random().toString(36).substring(2, 9)}` as Uuid,
				name: () => 'DEFAULT_NAME',
				roles: () => ['default_role'],
			};

			this.init();
		}
	}

	const cell = new NoInputJsonTestCell({
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
	// Create a modified test cell specifically for this test
	class UndefinedJsonTestCell extends Cell<typeof Test_Schema> {
		name: string = $state()!;
		age: number | undefined = $state();
		roles: Array<string> = $state()!;
		active: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);

			// Ensure id parser always returns a generated id pattern for this test
			this.parsers = {
				id: () => `generated-${Math.random().toString(36).substring(2, 9)}` as Uuid,
				name: () => 'DEFAULT_NAME',
				roles: () => ['default_role'],
			};

			this.init();
		}
	}

	// Test with explicitly undefined JSON
	const cell = new UndefinedJsonTestCell({
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
		json: {
			id: TEST_UUID,
			created: TEST_DATE,
			name: 'Snapshot Test',
		},
	});

	// Test JSON serialization
	const json = cell.json;
	expect(json.id).toBe(TEST_UUID);
	expect(json.name).toBe('SNAPSHOT TEST'); // Uppercase due to parser

	// Test JSON string serialization
	const json_string = cell.json_serialized;
	expect(json_string).toContain(`"id":"${TEST_UUID}"`);
	expect(json_string).toContain('"name":"SNAPSHOT TEST"');

	// Test toJSON method (used by $state.snapshot)
	const snapshot = $state.snapshot(cell);
	expect(snapshot.id).toBe(TEST_UUID);
});

test('Cell cloning creates proper copies', () => {
	const original = new Test_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_UUID,
			created: TEST_DATE,
			name: 'Original Cell',
		},
	});

	const clone = original.clone();

	// Clones should have same values
	expect(clone.id).toBe(TEST_UUID);
	expect(clone.name).toBe('ORIGINAL CELL');

	// But be different instances
	expect(clone).not.toBe(original);

	// Modifying clone shouldn't affect original
	clone.name = 'MODIFIED CLONE';
	expect(clone.name).toBe('MODIFIED CLONE');
	expect(original.name).toBe('ORIGINAL CELL');
});
