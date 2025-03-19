// @vitest-environment jsdom

import {test, expect, vi, beforeEach} from 'vitest';
import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Uuid, Datetime_Now} from '$lib/zod_helpers.js';
import {SvelteMap} from 'svelte/reactivity';

/* eslint-disable no-new */

// Basic schema for testing
const Basic_Test_Schema = Cell_Json.extend({
	name: z.string().default(''),
	value: z.number().default(0),
	tags: z.array(z.string()).default([]),
});

// Mock Zzz instance with cells SvelteMap for registration testing
const create_mock_zzz = () => {
	return {
		cells: new SvelteMap<Uuid, Cell>(),
		registry: {
			maybe_instantiate: vi.fn(),
		},
	} as any;
};

// Basic test cell implementation
class Basic_Test_Cell extends Cell<typeof Basic_Test_Schema> {
	name: string = $state()!;
	value: number = $state()!;
	tags: Array<string> = $state()!;

	constructor(options: Cell_Options<typeof Basic_Test_Schema>) {
		super(Basic_Test_Schema, options);
		this.init();
	}
}

// Setup for each test
beforeEach(() => {
	vi.clearAllMocks();
});

test('Cell initialization and registration', () => {
	const mock_zzz = create_mock_zzz();
	const test_id = Uuid.parse(undefined);
	const test_date = new Date().toISOString();

	const test_cell = new Basic_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: test_id,
			created: test_date,
			name: 'Test',
			value: 42,
			tags: ['tag1', 'tag2'],
		},
	});

	// Verify basic properties
	expect(test_cell.id).toBe(test_id);
	expect(test_cell.created).toBe(test_date);
	expect(test_cell.updated).toBeNull();
	expect(test_cell.name).toBe('Test');
	expect(test_cell.value).toBe(42);
	expect(test_cell.tags).toEqual(['tag1', 'tag2']);

	// Verify cell was registered
	expect(mock_zzz.cells.has(test_id)).toBe(true);
	expect(mock_zzz.cells.get(test_id)).toBe(test_cell);
});

test('Cell registration is idempotent', () => {
	const mock_zzz = create_mock_zzz();
	const console_error_spy = vi.spyOn(console, 'error');

	const test_cell = new Basic_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: Uuid.parse(undefined),
		},
	});

	// Cell should be registered automatically in init()
	expect(mock_zzz.cells.size).toBe(1);

	// Try to register again manually
	test_cell['register'](); // Access protected method for testing

	// Should have logged an error but not changed the registry
	expect(console_error_spy).toHaveBeenCalled();
	expect(mock_zzz.cells.size).toBe(1);

	console_error_spy.mockRestore();
});

test('Cell unregistration removes from registry', () => {
	const mock_zzz = create_mock_zzz();

	const test_cell = new Basic_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: Uuid.parse(undefined),
		},
	});

	// Cell should be registered automatically
	expect(mock_zzz.cells.size).toBe(1);

	// Unregister cell
	test_cell['dispose'](); // Access protected method for testing

	// Should be removed from registry
	expect(mock_zzz.cells.size).toBe(0);
});

test('Cell unregistration is safe to call multiple times', () => {
	const mock_zzz = create_mock_zzz();

	const test_cell = new Basic_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: Uuid.parse(undefined),
		},
	});

	// Unregister once
	test_cell['unregister'](); // Access protected method for testing
	expect(mock_zzz.cells.size).toBe(0);

	// Unregister again - should be safe
	expect(() => test_cell['unregister']()).not.toThrow();
});

test('Cell uses default values when json is empty', () => {
	const mock_zzz = create_mock_zzz();

	const test_cell = new Basic_Test_Cell({
		zzz: mock_zzz,
	});

	// Should use schema defaults
	expect(test_cell.id).toBeDefined();
	expect(test_cell.created).toBeDefined();
	expect(test_cell.updated).toBeNull();
	expect(test_cell.name).toBe('');
	expect(test_cell.value).toBe(0);
	expect(test_cell.tags).toEqual([]);
});

test('Cell formatters handle dates correctly', () => {
	const mock_zzz = create_mock_zzz();
	const now = new Date();
	const created = now.toISOString();
	const updated = new Date(now.getTime() + 10000).toISOString();

	const test_cell = new Basic_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: Uuid.parse(undefined),
			created,
			updated,
		},
	});

	// Verify date formatting properties
	expect(test_cell.created_date).toBeInstanceOf(Date);
	expect(test_cell.created_formatted_short_date).toBeDefined();
	expect(test_cell.created_formatted_date).toBeDefined();
	expect(test_cell.created_formatted_time).toBeDefined();

	expect(test_cell.updated_date).toBeInstanceOf(Date);
	expect(test_cell.updated_formatted_short_date).toBeDefined();
	expect(test_cell.updated_formatted_date).toBeDefined();
	expect(test_cell.updated_formatted_time).toBeDefined();
});

test('Cell to_json creates correct representation', () => {
	const mock_zzz = create_mock_zzz();
	const test_id = Uuid.parse(undefined);
	const created = Datetime_Now.parse(undefined);

	const test_cell = new Basic_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: test_id,
			created,
			name: 'JSON Test',
			value: 100,
			tags: ['json', 'test'],
		},
	});

	const json = test_cell.to_json();

	expect(json.id).toBe(test_id);
	expect(json.created).toBe(created);
	expect(json.name).toBe('JSON Test');
	expect(json.value).toBe(100);
	expect(json.tags).toEqual(['json', 'test']);
});

test('Cell toJSON method works with JSON.stringify', () => {
	const mock_zzz = create_mock_zzz();
	const test_id = Uuid.parse(undefined);

	const test_cell = new Basic_Test_Cell({
		zzz: mock_zzz,
		json: {
			id: test_id,
			name: 'Stringify Test',
		},
	});

	const stringified = JSON.stringify(test_cell);
	const parsed = JSON.parse(stringified);

	expect(parsed.id).toBe(test_id);
	expect(parsed.name).toBe('Stringify Test');
});

test('Cell json_serialized and json_parsed are derived correctly', () => {
	const mock_zzz = create_mock_zzz();

	const test_cell = new Basic_Test_Cell({
		zzz: mock_zzz,
		json: {
			name: 'Derived Test',
			value: 123,
		},
	});

	// Check derived properties
	expect(test_cell.json.name).toBe('Derived Test');
	expect(test_cell.json.value).toBe(123);

	const parsed = JSON.parse(test_cell.json_serialized);
	expect(parsed.name).toBe('Derived Test');
	expect(parsed.value).toBe(123);

	expect(test_cell.json_parsed.success).toBe(true);
});

test('Cell clone creates independent copy', () => {
	const mock_zzz = create_mock_zzz();

	const original = new Basic_Test_Cell({
		zzz: mock_zzz,
		json: {
			name: 'Original',
			value: 42,
			tags: ['tag1'],
		},
	});

	const clone = original.clone();

	// Should have same values
	expect(clone.name).toBe('Original');
	expect(clone.value).toBe(42);
	expect(clone.tags).toEqual(['tag1']);

	// But be a different instance
	expect(clone).not.toBe(original);

	// Changes to one shouldn't affect the other
	clone.name = 'Changed';
	clone.value = 100;
	clone.tags.push('tag2');

	expect(original.name).toBe('Original');
	expect(original.value).toBe(42);
	expect(original.tags).toEqual(['tag1']);
});

test('Cell set_json rejects invalid data', () => {
	const mock_zzz = create_mock_zzz();
	const test_cell = new Basic_Test_Cell({zzz: mock_zzz});

	// Should reject invalid data with a schema error
	expect(() => test_cell.set_json({value: 'not a number' as any})).toThrow();
});

test('Cell schema_keys and field_schemas are derived correctly', () => {
	const mock_zzz = create_mock_zzz();
	const test_cell = new Basic_Test_Cell({zzz: mock_zzz});

	// Check if schema keys contain expected fields
	expect(test_cell.schema_keys).toContain('id');
	expect(test_cell.schema_keys).toContain('name');
	expect(test_cell.schema_keys).toContain('value');
	expect(test_cell.schema_keys).toContain('tags');

	// Check if field schemas are correctly mapped
	expect(test_cell.field_schemas.size).toBeGreaterThan(0);
	expect(test_cell.field_schemas.has('name')).toBe(true);
	expect(test_cell.field_schemas.has('value')).toBe(true);
});

test('Cell schema_info provides type information', () => {
	const mock_zzz = create_mock_zzz();
	const test_cell = new Basic_Test_Cell({zzz: mock_zzz});

	const tags_info = test_cell.field_schema_info.get('tags');
	console.log(`tags_info`, tags_info);
	console.log(
		`Array.from(test_cell.field_schema_info.entries())`,
		Array.from(test_cell.field_schema_info.entries()),
	);
	expect(tags_info?.is_array).toBe(true);
	expect(tags_info?.type).toBe('ZodArray');

	const name_info = test_cell.field_schema_info.get('name');
	expect(name_info?.is_array).toBe(false);
	expect(name_info?.type).toBe('ZodString');
});
