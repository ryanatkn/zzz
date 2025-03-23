// @vitest-environment jsdom

import {test, expect, vi, beforeEach} from 'vitest';
import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json, type Schema_Keys} from '$lib/cell_types.js';
import {Uuid, Datetime_Now} from '$lib/zod_helpers.js';
import {HANDLED} from '$lib/cell_helpers.js';
import {Zzz} from '$lib/zzz.svelte.js';
import {monkeypatch_zzz_for_tests} from '$lib/test_helpers.js';

// Constants for testing
const TEST_ID = 'a0000000-0000-0000-0000-000000000001' as Uuid;
const TEST_DATE = Datetime_Now.parse(undefined);

// Test suite variables
let zzz: Zzz;

beforeEach(() => {
	// Create a real Zzz instance for each test
	zzz = monkeypatch_zzz_for_tests(new Zzz());
	vi.clearAllMocks();
});

// Base test schema that extends Cell_Json
const Test_Schema = Cell_Json.extend({
	text: z.string().default(''),
	number: z.number().optional(),
	list: z
		.array(z.string())
		.optional()
		.default(() => []),
	flag: z.boolean().default(true),
}).strict();

test('Cell supports overriding assign_property', () => {
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
		zzz,
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

test('Cell assign_property returns after handling property correctly', () => {
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
		zzz,
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

test('Cell handles inherited properties correctly', () => {
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
		zzz,
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

test('Cell properly handles collections with HANDLED sentinel', () => {
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
		zzz,
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

test('Cell registration and unregistration works correctly', () => {
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
		zzz,
		json: {
			id: cell_id,
			created: TEST_DATE,
		},
	});

	// Cell should be automatically registered
	expect(zzz.cells.has(cell_id)).toBe(true);
	expect(zzz.cells.get(cell_id)).toBe(cell);

	// Test disposal
	cell.dispose();
	expect(zzz.cells.has(cell_id)).toBe(false);

	// Test that disposing again is safe
	expect(() => cell.dispose()).not.toThrow();
});
