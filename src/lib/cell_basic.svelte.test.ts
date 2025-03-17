// @vitest-environment jsdom

import {test, expect, vi, beforeEach} from 'vitest';
import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Uuid, Datetime_Now} from '$lib/zod_helpers.js';
import {HANDLED, USE_DEFAULT} from '$lib/cell_helpers.js';

/* eslint-disable no-new */

// Simple mock for Zzz
const mock_zzz = {
	registry: {
		instantiate: vi.fn((name, json) => {
			// For testing instantiation logic
			if (name === 'Mock_Type' && json) {
				return {type: 'Mock_Type', ...json};
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
const TEST_ID = 'a0000000-0000-0000-0000-000000000001';
const TEST_ID2 = 'a0000000-0000-0000-0000-000000000002';

// Create a date string for test data
const TEST_DATE = new Date().toISOString();

// Test schema that extends the base Cell_Json schema
const Test_Schema = Cell_Json.extend({
	txt: z.string().optional().default(''),
	num: z.number().optional(),
	arr: z
		.array(z.string())
		.optional()
		.default(() => []),
	flg: z.boolean().default(true),
}).strict();

// Test Cell implementation
class Test_Cell extends Cell<typeof Test_Schema> {
	txt: string = $state()!;
	num: number | undefined = $state();
	arr: Array<string> = $state()!;
	flg: boolean = $state()!;

	constructor(options: Cell_Options<typeof Test_Schema>) {
		super(Test_Schema, options);

		// Set up parsers
		this.decoders = {
			id: (value) => {
				if (typeof value === 'string' && value.length > 0) {
					return value as Uuid; // Keep existing non-empty value
				}
				// Handle default value generation
				return `gen-${Math.random().toString(36).substring(2, 7)}` as Uuid;
			},
			txt: (value) => {
				if (typeof value === 'string' && value !== '') {
					return value.toUpperCase();
				}
				// Handle default value generation
				return 'DEFAULT';
			},
			arr: (value) => {
				if (Array.isArray(value) && value.length > 0) {
					return value.map((r) => (typeof r === 'string' ? r.toLowerCase() : String(r)));
				}
				// Handle default value generation
				return ['item0'];
			},
		};

		this.init();
	}
}

test('Cell with parsers decodes values correctly', () => {
	const cell = new Test_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			updated: null,
			txt: 'abc',
			num: 123,
			arr: ['X1', 'Y2', 'Z3'],
		},
	});

	// txt should be uppercase due to parser
	expect(cell.txt).toBe('ABC');

	// arr should be lowercase due to parser
	expect(cell.arr).toEqual(['x1', 'y2', 'z3']);

	// Other fields should be parsed normally
	expect(cell.id).toBe(TEST_ID);
	expect(cell.num).toBe(123);
	expect(cell.flg).toBe(true); // Default value
});

test('Cell parsers return undefined to use default decoding', () => {
	// Create a cell with a parser that returns undefined for some values
	class Partial_Parser_Cell extends Cell<typeof Test_Schema> {
		txt: string = $state()!;
		num: number | undefined = $state();
		arr: Array<string> = $state()!;
		flg: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);

			this.decoders = {
				txt: (value) => {
					// Only transform texts that start with 'a'
					if (typeof value === 'string' && value.startsWith('a')) {
						return value.toUpperCase();
					}
					// For other texts, return undefined to use default parsing
					return undefined;
				},
			};

			this.init();
		}
	}

	const cell1 = new Partial_Parser_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			txt: 'abc',
			arr: [],
		},
	});

	const cell2 = new Partial_Parser_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID2,
			created: TEST_DATE,
			txt: 'xyz',
			arr: [],
		},
	});

	// 'abc' starts with 'a', so it should be uppercase
	expect(cell1.txt).toBe('ABC');

	// 'xyz' doesn't start with 'a', so it should remain as-is
	expect(cell2.txt).toBe('xyz');
});

test('Cell parsers provide default values', () => {
	// Test with minimal JSON - just specify required fields
	const cell = new Test_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
		},
	});

	// id should come from JSON and be processed by parser
	expect(cell.id).toBe(TEST_ID);

	// txt should come from parser
	expect(cell.txt).toBe('DEFAULT');

	// arr should come from parser
	expect(cell.arr).toEqual(['item0']);

	// flg should come from schema default
	expect(cell.flg).toBe(true);

	// num has no parser or schema default
	expect(cell.num).toBeUndefined();
});

test('Cell parsers are only applied for appropriate values', () => {
	// Test with complete JSON
	const cell = new Test_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			txt: 'value',
			arr: ['item1'],
			flg: false,
		},
	});

	// Values should come from JSON, with parser transformations
	expect(cell.id).toBe(TEST_ID);
	expect(cell.txt).toBe('VALUE'); // Uppercase due to parser
	expect(cell.arr).toEqual(['item1']); // Lowercase due to parser
	expect(cell.flg).toBe(false);
});

test('Cell parsers work with empty JSON', () => {
	// Create a modified test cell specifically for this test
	class Empty_Json_Cell extends Cell<typeof Test_Schema> {
		txt: string = $state()!;
		num: number | undefined = $state();
		arr: Array<string> = $state()!;
		flg: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);

			// Ensure id parser always returns a generated id pattern for this test
			this.decoders = {
				id: () => `gen-${Math.random().toString(36).substring(2, 7)}` as Uuid,
				txt: () => 'DEFAULT',
				arr: () => ['item0'],
			};

			this.init();
		}
	}

	// Test with empty JSON - this is now valid due to schema default/optional fields
	const cell = new Empty_Json_Cell({
		zzz: mock_zzz,
		json: {},
	});

	// Values should come from parsers
	expect(cell.id).toMatch(/^gen-/); // Generated ID
	expect(cell.txt).toBe('DEFAULT');
	expect(cell.arr).toEqual(['item0']);
	expect(cell.flg).toBe(true); // Schema default
});

test('Cell with no parsers uses schema defaults', () => {
	// Create a custom test schema with string ID for easier testing
	const Basic_Schema = z
		.object({
			id: z.string().default(''),
			created: z
				.string()
				.datetime()
				.default(() => new Date().toISOString()),
			updated: z.string().nullable().default(null),
			txt: z.string().default(''),
			num: z.number().optional(),
			arr: z.array(z.string()).default(() => []),
			flg: z.boolean().default(true),
		})
		.strict();

	class Default_Cell extends Cell<typeof Basic_Schema> {
		txt: string = $state()!;
		num: number | undefined = $state();
		arr: Array<string> = $state()!;
		flg: boolean = $state()!;

		constructor(options: Cell_Options<typeof Basic_Schema>) {
			super(Basic_Schema, options);
			this.init();
		}
	}

	const cell = new Default_Cell({
		zzz: mock_zzz,
		json: {}, // Empty JSON is valid due to schema defaults/optional
	});

	// flg has a schema default
	expect(cell.flg).toBe(true);

	// These have defaults in the schema (empty string/array)
	expect(cell.id).toBe('');
	expect(cell.txt).toBe('');
	expect(cell.arr).toEqual([]);
	expect(cell.num).toBeUndefined();
});

test('Cell parsers can depend on instance properties', () => {
	class Instance_Cell extends Cell<typeof Test_Schema> {
		txt: string = $state()!;
		num: number | undefined = $state();
		arr: Array<string> = $state()!;
		flg: boolean = $state()!;

		counter = 1; // Not part of schema, just for testing

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);

			this.decoders = {
				// Always return values based on instance properties
				id: () => `id-${this.counter}` as Uuid,
				txt: () => `txt-${this.counter}`,
				arr: () => [`item-${this.counter}`],
			};

			this.init();
		}
	}

	const cell = new Instance_Cell({
		zzz: mock_zzz,
		json: {}, // Empty JSON is valid due to schema defaults/optional
	});

	// Values should be generated using instance properties
	expect(cell.id).toBe('id-1');
	expect(cell.txt).toBe('txt-1');
	expect(cell.arr).toEqual(['item-1']);
});

test('Cell throws validation errors from schema', () => {
	// Make a schema with specific validation rules
	const schema = z.object({
		id: Uuid,
		created: Datetime_Now,
		updated: z.string().nullable().default(null),
		txt: z.string().nonempty(), // Must not be empty
	});

	class Validation_Cell extends Cell<typeof schema> {
		txt: string = $state()!;

		constructor(options: Cell_Options<typeof schema>) {
			super(schema, options);
			this.init();
		}
	}

	// Should throw because txt is empty
	expect(
		() =>
			new Validation_Cell({
				zzz: mock_zzz,
				json: {
					id: TEST_ID,
					created: TEST_DATE,
					txt: '', // Empty txt, should fail
				},
			}),
	).toThrow();

	// Should not throw with valid data
	expect(
		() =>
			new Validation_Cell({
				zzz: mock_zzz,
				json: {
					id: TEST_ID,
					created: TEST_DATE,
					txt: 'valid', // Valid txt
				},
			}),
	).not.toThrow();
});

test('Cell parsers run even with no input JSON', () => {
	// Create a modified test cell specifically for this test
	class No_Input_Cell extends Cell<typeof Test_Schema> {
		txt: string = $state()!;
		num: number | undefined = $state();
		arr: Array<string> = $state()!;
		flg: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);

			// Ensure id parser always returns a generated id pattern for this test
			this.decoders = {
				id: () => `gen-${Math.random().toString(36).substring(2, 7)}` as Uuid,
				txt: () => 'DEFAULT',
				arr: () => ['item0'],
			};

			this.init();
		}
	}

	const cell = new No_Input_Cell({
		zzz: mock_zzz,
		// No json provided at all
	});

	// Should still get values from parsers
	expect(cell.id).toMatch(/^gen-/);
	expect(cell.txt).toBe('DEFAULT');
	expect(cell.arr).toEqual(['item0']);
	expect(cell.flg).toBe(true);
});

test('Cell handles undefined JSON input correctly', () => {
	// Create a modified test cell specifically for this test
	class Undefined_Json_Cell extends Cell<typeof Test_Schema> {
		txt: string = $state()!;
		num: number | undefined = $state();
		arr: Array<string> = $state()!;
		flg: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);

			// Ensure id parser always returns a generated id pattern for this test
			this.decoders = {
				id: () => `gen-${Math.random().toString(36).substring(2, 7)}` as Uuid,
				txt: () => 'DEFAULT',
				arr: () => ['item0'],
			};

			this.init();
		}
	}

	// Test with explicitly undefined JSON
	const cell = new Undefined_Json_Cell({
		zzz: mock_zzz,
		json: undefined,
	});

	// Should handle undefined gracefully with parsers
	expect(cell.id).toMatch(/^gen-/);
	expect(cell.txt).toBe('DEFAULT');
	expect(cell.arr).toEqual(['item0']);
});

test('Cell has proper snapshot and serialization support', () => {
	const cell = new Test_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			txt: 'value',
		},
	});

	// Test JSON serialization
	const json = cell.json;
	expect(json.id).toBe(TEST_ID);
	expect(json.txt).toBe('VALUE'); // Uppercase due to parser

	// Test JSON string serialization
	const json_string = cell.json_serialized;
	expect(json_string).toContain(`"id":"${TEST_ID}"`);
	expect(json_string).toContain('"txt":"VALUE"');

	// Test toJSON method (used by $state.snapshot)
	const snapshot = $state.snapshot(cell);
	expect(snapshot.id).toBe(TEST_ID);
});

test('Cell cloning creates proper copies', () => {
	const original = new Test_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			txt: 'original',
		},
	});

	const clone = original.clone();

	// Clones should have same values
	expect(clone.id).toBe(TEST_ID);
	expect(clone.txt).toBe('ORIGINAL');

	// But be different instances
	expect(clone).not.toBe(original);

	// Modifying clone shouldn't affect original
	clone.txt = 'MODIFIED';
	expect(clone.txt).toBe('MODIFIED');
	expect(original.txt).toBe('ORIGINAL');
});

test('Cell parsers can return USE_DEFAULT sentinel to explicitly use default decoding', () => {
	class Default_Sentinel_Cell extends Cell<typeof Test_Schema> {
		txt: string = $state()!;
		num: number | undefined = $state();
		arr: Array<string> = $state()!;
		flg: boolean = $state()!;

		constructor(options: Cell_Options<typeof Test_Schema>) {
			super(Test_Schema, options);

			this.decoders = {
				txt: (value) => {
					// Only transform values starting with "a"
					if (typeof value === 'string' && value.startsWith('a')) {
						return value.toUpperCase();
					}
					// Explicitly use default parsing for other values
					return USE_DEFAULT;
				},
			};

			this.init();
		}
	}

	const cell1 = new Default_Sentinel_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			txt: 'abc',
			arr: [],
		},
	});

	const cell2 = new Default_Sentinel_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID2,
			created: TEST_DATE,
			txt: 'xyz',
			arr: [],
		},
	});

	// 'abc' should be uppercase
	expect(cell1.txt).toBe('ABC');

	// 'xyz' should remain as-is through default decoding
	expect(cell2.txt).toBe('xyz');
});

test('Cell parsers use HANDLED sentinel for virtual properties', () => {
	// Schema with both real and virtual properties
	const Virtual_Schema = Cell_Json.extend({
		real_prop: z.string().default('default'),
		virtual_prop: z.number().default(42), // This property won't exist on the class
	});

	const console_error_spy = vi.spyOn(console, 'error');

	class Virtual_Cell extends Cell<typeof Virtual_Schema> {
		real_prop: string = $state()!;
		// No virtual_prop property

		stored_value = 0; // Just for tracking parser behavior

		constructor(options: Cell_Options<typeof Virtual_Schema>) {
			super(Virtual_Schema, options);

			this.decoders = {
				virtual_prop: (value) => {
					// Store value for testing
					if (typeof value === 'number') {
						this.stored_value = value * 2;
					}
					// Return HANDLED for virtual property
					return HANDLED;
				},
			};

			this.init();
		}
	}

	const cell = new Virtual_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			real_prop: 'value',
			virtual_prop: 100,
		},
	});

	// Real property should be set
	expect(cell.real_prop).toBe('value');

	// Virtual property should be processed
	expect(cell.stored_value).toBe(200); // 100 * 2

	// No error should be logged for virtual property
	const found_error = console_error_spy.mock.calls.some((args) =>
		args.join(' ').includes("didn't return HANDLED for virtual property"),
	);
	expect(found_error).toBe(false);

	console_error_spy.mockRestore();
});

test("Cell logs error when virtual property parser doesn't return HANDLED", () => {
	// Schema with virtual property
	const Bad_Virtual_Schema = Cell_Json.extend({
		real_prop: z.string().default('default'),
		virtual_prop: z.number().default(42), // This property won't exist on the class
	});

	const console_error_spy = vi.spyOn(console, 'error');

	class Bad_Virtual_Cell extends Cell<typeof Bad_Virtual_Schema> {
		real_prop: string = $state()!;
		// No virtual_prop property

		constructor(options: Cell_Options<typeof Bad_Virtual_Schema>) {
			super(Bad_Virtual_Schema, options);

			this.decoders = {
				virtual_prop: (_value) => {
					// Incorrectly returning undefined for virtual property
					return undefined;
				},
			};

			this.init();
		}
	}

	// Should work but log an error
	new Bad_Virtual_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			real_prop: 'value',
			virtual_prop: 100,
		},
	});

	// The expected error message should have been logged
	const error_message = `Decoder for schema property "virtual_prop" in Bad_Virtual_Cell didn't return HANDLED`;
	const found_error = console_error_spy.mock.calls.some((args) =>
		args.join(' ').includes(error_message),
	);
	expect(found_error).toBe(true);

	console_error_spy.mockRestore();
});

test('Cell does not allow USE_DEFAULT for virtual properties', () => {
	// Schema with virtual property
	const Use_Default_Virtual_Schema = Cell_Json.extend({
		real_prop: z.string().default('default'),
		virtual_prop: z.number().default(42), // This property won't exist on the class
	});

	const console_error_spy = vi.spyOn(console, 'error');

	class Use_Default_Virtual_Cell extends Cell<typeof Use_Default_Virtual_Schema> {
		real_prop: string = $state()!;
		// No virtual_prop property

		constructor(options: Cell_Options<typeof Use_Default_Virtual_Schema>) {
			super(Use_Default_Virtual_Schema, options);

			this.decoders = {
				virtual_prop: (_value) => {
					// Incorrectly returning USE_DEFAULT for virtual property
					return USE_DEFAULT;
				},
			};

			this.init();
		}
	}

	// Should work but log an error
	new Use_Default_Virtual_Cell({
		zzz: mock_zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATE,
			real_prop: 'value',
			virtual_prop: 100,
		},
	});

	// The expected error message should have been logged
	const error_message = `Decoder for "virtual_prop" in Use_Default_Virtual_Cell returned USE_DEFAULT but no property exists`;
	const found_error = console_error_spy.mock.calls.some((args) =>
		args.join(' ').includes(error_message),
	);
	expect(found_error).toBe(true);

	console_error_spy.mockRestore();
});