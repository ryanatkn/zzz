import {test, expect, vi} from 'vitest';
import * as path from 'node:path';

import {ZZZ_DIR, parse_zzz_dirs} from '$lib/server/server_helpers.js';
import {Zzz_Dir} from '$lib/diskfile_types.js';

// Mock environment variables
vi.mock('$env/static/public', () => ({
	PUBLIC_ZZZ_DIRS: './test_dir1:/tmp/test_dir2',
}));

test('parse_zzz_dirs - should parse from string with colon separator', () => {
	const input = './dir1:/tmp/dir2:./another_dir';
	const result = parse_zzz_dirs(input);

	expect(result).toHaveLength(3);
	expect(result[0]).toBe(Zzz_Dir.parse(path.resolve('./dir1')));
	expect(result[1]).toBe(Zzz_Dir.parse(path.resolve('/tmp/dir2')));
	expect(result[2]).toBe(Zzz_Dir.parse(path.resolve('./another_dir')));
	expect(Object.isFrozen(result)).toBe(true);
});

test('parse_zzz_dirs - should handle array input', () => {
	const input = ['./dir1', '/tmp/dir2', './another_dir'];
	const result = parse_zzz_dirs(input);

	expect(result).toHaveLength(3);
	expect(result[0]).toBe(Zzz_Dir.parse(path.resolve('./dir1')));
	expect(result[1]).toBe(Zzz_Dir.parse(path.resolve('/tmp/dir2')));
	expect(result[2]).toBe(Zzz_Dir.parse(path.resolve('./another_dir')));
});

test('parse_zzz_dirs - should use default when given empty input', () => {
	const empty_string_result = parse_zzz_dirs('');
	expect(empty_string_result).toHaveLength(1);
	expect(empty_string_result[0]).toBe(Zzz_Dir.parse(path.resolve(ZZZ_DIR)));

	const empty_array_result = parse_zzz_dirs([]);
	expect(empty_array_result).toHaveLength(1);
	expect(empty_array_result[0]).toBe(Zzz_Dir.parse(path.resolve(ZZZ_DIR)));
});

test('parse_zzz_dirs - should trim whitespace from directory entries', () => {
	const input = ' ./dir1 : /tmp/dir2  :  ./another_dir ';
	const result = parse_zzz_dirs(input);

	expect(result).toHaveLength(3);
	expect(result[0]).toBe(Zzz_Dir.parse(path.resolve('./dir1')));
	expect(result[1]).toBe(Zzz_Dir.parse(path.resolve('/tmp/dir2')));
	expect(result[2]).toBe(Zzz_Dir.parse(path.resolve('./another_dir')));
});

test('parse_zzz_dirs - should filter empty entries', () => {
	const input = './dir1:::/tmp/dir2::';
	const result = parse_zzz_dirs(input);

	expect(result).toHaveLength(2);
	expect(result[0]).toBe(Zzz_Dir.parse(path.resolve('./dir1')));
	expect(result[1]).toBe(Zzz_Dir.parse(path.resolve('/tmp/dir2')));
});

test('parse_zzz_dirs - should resolve relative paths', () => {
	const input = './relative_path:../parent_path';
	const result = parse_zzz_dirs(input);

	expect(result[0]).toBe(Zzz_Dir.parse(path.resolve('./relative_path')));
	expect(result[1]).toBe(Zzz_Dir.parse(path.resolve('../parent_path')));
});

test('parse_zzz_dirs - should handle mixed array with colons in strings', () => {
	const input = ['./dir1', '/tmp/dir2:./dir3', './dir4:./dir5'];
	const result = parse_zzz_dirs(input);

	expect(result).toHaveLength(5);
	expect(result[0]).toBe(Zzz_Dir.parse(path.resolve('./dir1')));
	expect(result[1]).toBe(Zzz_Dir.parse(path.resolve('/tmp/dir2')));
	expect(result[2]).toBe(Zzz_Dir.parse(path.resolve('./dir3')));
	expect(result[3]).toBe(Zzz_Dir.parse(path.resolve('./dir4')));
	expect(result[4]).toBe(Zzz_Dir.parse(path.resolve('./dir5')));
});

test('parse_zzz_dirs - should handle invalid array entries gracefully', () => {
	const input = ['./dir1', null as any, undefined as any, 123 as any, './dir2'];
	const result = parse_zzz_dirs(input);

	// Should only have the valid string entries
	expect(result).toHaveLength(2);
	expect(result[0]).toBe(Zzz_Dir.parse(path.resolve('./dir1')));
	expect(result[1]).toBe(Zzz_Dir.parse(path.resolve('./dir2')));
});

test('parse_zzz_dirs - should use default value when no argument is provided', () => {
	// This will use the mocked PUBLIC_ZZZ_DIRS value
	const result = parse_zzz_dirs();

	expect(result).toHaveLength(2);
	expect(result[0]).toBe(Zzz_Dir.parse(path.resolve('./test_dir1')));
	expect(result[1]).toBe(Zzz_Dir.parse(path.resolve('/tmp/test_dir2')));
});

test('parse_zzz_dirs - should handle type-unsafe inputs', () => {
	// Test with null and undefined
	const null_result = parse_zzz_dirs(null as any);
	expect(null_result).toHaveLength(1);
	expect(null_result[0]).toBe(Zzz_Dir.parse(path.resolve(ZZZ_DIR)));

	const undefined_result = parse_zzz_dirs(undefined);
	// Should use the default from PUBLIC_ZZZ_DIRS
	expect(undefined_result).toHaveLength(2);
	expect(undefined_result[0]).toBe(Zzz_Dir.parse(path.resolve('./test_dir1')));
	expect(undefined_result[1]).toBe(Zzz_Dir.parse(path.resolve('/tmp/test_dir2')));

	// Test with numbers and objects
	const number_result = parse_zzz_dirs(123 as any);
	expect(number_result).toHaveLength(1);
	expect(number_result[0]).toBe(Zzz_Dir.parse(path.resolve(ZZZ_DIR)));

	const object_result = parse_zzz_dirs({} as any);
	expect(object_result).toHaveLength(1);
	expect(object_result[0]).toBe(Zzz_Dir.parse(path.resolve(ZZZ_DIR)));
});

test('parse_zzz_dirs - should handle leading colon', () => {
	const input = ':/dir1:/dir2';
	const result = parse_zzz_dirs(input);
	// Leading empty entry should be filtered out; expect two valid entries
	expect(result).toHaveLength(2);
	expect(result[0]).toBe(Zzz_Dir.parse(path.resolve('/dir1')));
	expect(result[1]).toBe(Zzz_Dir.parse(path.resolve('/dir2')));
});

test('parse_zzz_dirs - should handle trailing colon', () => {
	const input = '/dir1:/dir2:';
	const result = parse_zzz_dirs(input);
	// Trailing empty entry should be filtered out; expect two valid entries
	expect(result).toHaveLength(2);
	expect(result[0]).toBe(Zzz_Dir.parse(path.resolve('/dir1')));
	expect(result[1]).toBe(Zzz_Dir.parse(path.resolve('/dir2')));
});

test('parse_zzz_dirs - should handle input with only whitespace', () => {
	const input = '    ';
	const result = parse_zzz_dirs(input);
	// Whitespace-only input should yield the default directory
	expect(result).toHaveLength(1);
	expect(result[0]).toBe(Zzz_Dir.parse(path.resolve(ZZZ_DIR)));
});

test('parse_zzz_dirs - should return an immutable array', () => {
	const result = parse_zzz_dirs('./dir1');
	expect(Object.isFrozen(result)).toBe(true);
});

test('parse_zzz_dirs - should handle leading colons', () => {
	// Test single leading colon
	const input_single = ':/dir1:/dir2';
	const result_single = parse_zzz_dirs(input_single);
	expect(result_single).toHaveLength(2);
	expect(result_single[0]).toBe(Zzz_Dir.parse(path.resolve('/dir1')));
	expect(result_single[1]).toBe(Zzz_Dir.parse(path.resolve('/dir2')));

	// Test multiple leading colons
	const input_multiple = ':::::/dir1:/dir2';
	const result_multiple = parse_zzz_dirs(input_multiple);
	expect(result_multiple).toHaveLength(2);
	expect(result_multiple[0]).toBe(Zzz_Dir.parse(path.resolve('/dir1')));
	expect(result_multiple[1]).toBe(Zzz_Dir.parse(path.resolve('/dir2')));
});

test('parse_zzz_dirs - should handle trailing colons', () => {
	// Test single trailing colon
	const input_single = '/dir1:/dir2:';
	const result_single = parse_zzz_dirs(input_single);
	expect(result_single).toHaveLength(2);
	expect(result_single[0]).toBe(Zzz_Dir.parse(path.resolve('/dir1')));
	expect(result_single[1]).toBe(Zzz_Dir.parse(path.resolve('/dir2')));

	// Test multiple trailing colons
	const input_multiple = '/dir1:/dir2:::::';
	const result_multiple = parse_zzz_dirs(input_multiple);
	expect(result_multiple).toHaveLength(2);
	expect(result_multiple[0]).toBe(Zzz_Dir.parse(path.resolve('/dir1')));
	expect(result_multiple[1]).toBe(Zzz_Dir.parse(path.resolve('/dir2')));
});

test('parse_zzz_dirs - should handle various whitespace inputs', () => {
	// Test spaces
	const spaces_input = '    ';
	const spaces_result = parse_zzz_dirs(spaces_input);
	expect(spaces_result).toHaveLength(1);
	expect(spaces_result[0]).toBe(Zzz_Dir.parse(path.resolve(ZZZ_DIR)));

	// Test tabs
	const tabs_input = '\t\t\t';
	const tabs_result = parse_zzz_dirs(tabs_input);
	expect(tabs_result).toHaveLength(1);
	expect(tabs_result[0]).toBe(Zzz_Dir.parse(path.resolve(ZZZ_DIR)));

	// Test mixed whitespace
	const mixed_input = ' \t \n \r ';
	const mixed_result = parse_zzz_dirs(mixed_input);
	expect(mixed_result).toHaveLength(1);
	expect(mixed_result[0]).toBe(Zzz_Dir.parse(path.resolve(ZZZ_DIR)));

	// Test whitespace with colons
	const whitespace_colons_input = '  :  :  ';
	const whitespace_colons_result = parse_zzz_dirs(whitespace_colons_input);
	expect(whitespace_colons_result).toHaveLength(1);
	expect(whitespace_colons_result[0]).toBe(Zzz_Dir.parse(path.resolve(ZZZ_DIR)));
});

test('parse_zzz_dirs - should return a truly immutable array', () => {
	const result = parse_zzz_dirs('./dir1');

	// Test for basic immutability
	expect(Object.isFrozen(result)).toBe(true);

	// Attempt to modify the array and verify it fails in strict mode
	expect(() => {
		'use strict';
		// @ts-ignore - Intentionally trying to modify frozen array
		result[0] = 'modified';
	}).toThrow(TypeError);

	// Verify array contents haven't changed
	expect(result[0]).toBe(Zzz_Dir.parse(path.resolve('./dir1')));

	// Attempt to add to the array
	expect(() => {
		'use strict';
		// @ts-ignore - Intentionally trying to modify frozen array
		result.push('new-item');
	}).toThrow(TypeError);

	// Verify array length hasn't changed
	expect(result).toHaveLength(1);
});

// Test for combined edge cases
test('parse_zzz_dirs - should handle combined edge cases', () => {
	// Leading and trailing colons with whitespace
	const combined_input = ' : : /dir1 : /dir2 : : ';
	const result = parse_zzz_dirs(combined_input);
	expect(result).toHaveLength(2);
	expect(result[0]).toBe(Zzz_Dir.parse(path.resolve('/dir1')));
	expect(result[1]).toBe(Zzz_Dir.parse(path.resolve('/dir2')));
});
