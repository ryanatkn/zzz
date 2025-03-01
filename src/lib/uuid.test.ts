import {test, expect, vi} from 'vitest';
import {z} from 'zod';

import {Uuid, Uuid_Base} from '$lib/uuid.js';

// Basic functionality tests
test('Uuid - is a Zod branded string schema', () => {
	expect(Uuid).toBeInstanceOf(z.ZodType);
});

test('Uuid - accepts valid UUID strings', () => {
	const valid_uuid = '123e4567-e89b-12d3-a456-426614174000';
	const result = Uuid.safeParse(valid_uuid);
	expect(result.success).toBe(true);
	if (result.success) {
		expect(result.data).toBe(valid_uuid);
	}
});

test('Uuid - rejects invalid UUID strings', () => {
	const invalid_values = [
		'not-a-uuid',
		'123e4567-e89b-12d3-a456', // too short
		'123e4567-e89b-12d3-a456-4266141740000', // too long
		'123e4567-e89b-12d3-a456-42661417400g', // invalid character
		123456, // not a string
		{}, // not a string
		null, // not a string
		// undefined, // not a string
	];

	for (const value of invalid_values) {
		const result = Uuid.safeParse(value);
		expect(result.success).toBe(false);
	}
});

// Default behavior tests
test('Uuid - default generates a random UUID using crypto.randomUUID', () => {
	// Mock the crypto.randomUUID method
	const original_random_uuid = globalThis.crypto.randomUUID;
	const mock_uuid = '00000000-0000-0000-0000-000000000000';
	(globalThis.crypto as any).randomUUID = vi.fn(() => mock_uuid);

	try {
		// Test the default behavior
		const schema_with_default = Uuid.default(() => globalThis.crypto.randomUUID());
		const result = schema_with_default.parse(undefined);

		expect(globalThis.crypto.randomUUID).toHaveBeenCalledTimes(1);
		expect(result).toBe(mock_uuid);
	} finally {
		// Restore the original method
		globalThis.crypto.randomUUID = original_random_uuid;
	}
});

test('Uuid - built-in default works as expected', () => {
	// Get two default UUIDs
	const uuid1 = Uuid.parse(undefined);
	const uuid2 = Uuid.parse(undefined);

	// Verify they're valid UUIDs
	expect(typeof uuid1).toBe('string');
	expect(uuid1).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i);

	// Verify they're unique
	expect(uuid1).not.toBe(uuid2);
});

// Type safety tests
test('Uuid - type branding works properly', () => {
	// Verify that parse returns a branded UUID
	const uuid = Uuid.parse('123e4567-e89b-12d3-a456-426614174000');

	// This would fail type-checking if we could test types at runtime
	// But we can at least verify it's a string with the correct value
	expect(typeof uuid).toBe('string');
	expect(uuid).toBe('123e4567-e89b-12d3-a456-426614174000');
});

// Edge cases
test('Uuid - handles different UUID formats correctly', () => {
	// Test various valid UUID formats
	const uppercase_uuid = '123E4567-E89B-12D3-A456-426614174000';
	expect(Uuid.safeParse(uppercase_uuid).success).toBe(true);

	// Some systems might generate UUIDs without dashes
	const no_dashes = '123e4567e89b12d3a456426614174000';
	expect(Uuid.safeParse(no_dashes).success).toBe(false); // Should fail without dashes
});

test('Uuid - handles UUID versions correctly', () => {
	// Version 1 UUID (time-based)
	const v1_uuid = 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6';
	expect(Uuid.safeParse(v1_uuid).success).toBe(true);

	// Version 4 UUID (random)
	const v4_uuid = '123e4567-e89b-42d3-a456-426614174000';
	expect(Uuid.safeParse(v4_uuid).success).toBe(true);
});

test('Uuid - schema properties are retained after parse', () => {
	const parsed_uuid = Uuid.parse('123e4567-e89b-12d3-a456-426614174000');
	const reparsed = Uuid.parse(parsed_uuid);

	// Should be the same value
	expect(reparsed).toBe(parsed_uuid);
});

// Integration scenarios
test('Uuid - integrates with other Zod schemas', () => {
	// Create a schema that uses Uuid
	const TestSchema = z.object({
		id: Uuid,
		name: z.string(),
	});

	// Should validate correctly with a valid UUID
	const valid_result = TestSchema.safeParse({
		id: '123e4567-e89b-12d3-a456-426614174000',
		name: 'Test',
	});
	expect(valid_result.success).toBe(true);

	// Should fail with an invalid UUID
	const invalid_result = TestSchema.safeParse({
		id: 'not-a-uuid',
		name: 'Test',
	});
	expect(invalid_result.success).toBe(false);
});

test('Uuid - works with arrays and maps', () => {
	// Array of UUIDs
	const UuidArray = z.array(Uuid);
	const valid_uuids = [
		'123e4567-e89b-12d3-a456-426614174000',
		'123e4567-e89b-12d3-a456-426614174001',
	];

	const array_result = UuidArray.safeParse(valid_uuids);
	expect(array_result.success).toBe(true);

	// Map with UUID keys
	const UuidMap = z.record(Uuid, z.string());
	const valid_map = {
		'123e4567-e89b-12d3-a456-426614174000': 'value1',
		'123e4567-e89b-12d3-a456-426614174001': 'value2',
	};

	const map_result = UuidMap.safeParse(valid_map);
	expect(map_result.success).toBe(true);
});

// Error message tests
test('Uuid - provides helpful error messages', () => {
	const result = Uuid.safeParse('not-a-uuid');
	expect(result.success).toBe(false);

	if (!result.success) {
		// Check that the error message mentions UUID format
		expect(result.error.issues[0].message).toContain('uuid');
	}
});

// Performance considerations
test('Uuid - validation performance is reasonable', () => {
	const start_time = performance.now();

	// Validate 1000 UUIDs
	for (let i = 0; i < 1000; i++) {
		Uuid.safeParse('123e4567-e89b-12d3-a456-426614174000');
	}

	const end_time = performance.now();
	const duration = end_time - start_time;

	// This is a soft assertion - just checking it's not extremely slow
	// Typically, this should take just a few milliseconds
	expect(duration).toBeLessThan(1000); // Less than 1 second for 1000 validations
});

test('Uuid_Base - validates valid UUIDs', () => {
	const valid_uuid = '123e4567-e89b-12d3-a456-426614174000';
	expect(Uuid_Base.parse(valid_uuid)).toBe(valid_uuid);
});

test('Uuid_Base - rejects invalid UUIDs', () => {
	const invalid_uuid = 'not-a-uuid';
	expect(() => Uuid_Base.parse(invalid_uuid)).toThrow();
});

test('Uuid_Base - has no default value', () => {
	// The schema should not generate a default value
	expect(Uuid_Base.safeParse(undefined).success).toBe(false);
});

test('Uuid - validates valid UUIDs', () => {
	const valid_uuid = '123e4567-e89b-12d3-a456-426614174000';
	expect(Uuid.parse(valid_uuid)).toBe(valid_uuid);
});

test('Uuid - rejects invalid UUIDs', () => {
	const invalid_uuid = 'not-a-uuid';
	expect(() => Uuid.parse(invalid_uuid)).toThrow();
});

test('Uuid - generates random UUID as default', () => {
	// Mock the randomUUID function
	const mock_uuid = '123e4567-e89b-12d3-a456-426614174000';
	const crypto_spy = vi.spyOn(globalThis.crypto, 'randomUUID').mockReturnValue(mock_uuid);

	try {
		const result = Uuid.parse(undefined);
		expect(result).toBe(mock_uuid);
		expect(crypto_spy).toHaveBeenCalledTimes(1);
	} finally {
		crypto_spy.mockRestore();
	}
});
