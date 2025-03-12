import {test, expect, vi, beforeEach, afterEach} from 'vitest';
import * as fs from 'node:fs';
import {to_array} from '@ryanatkn/belt/array.js';

import {
	is_path_in_allowed_dirs,
	write_path_in_scope,
	delete_path_in_scope,
} from '$lib/server/filesystem_helpers.js';

// Mock filesystem functions
vi.mock('node:fs', () => ({
	writeFileSync: vi.fn(),
	rmSync: vi.fn(),
}));

// Reset mocks before each test
beforeEach(() => {
	vi.clearAllMocks();
});

// Restore mocks after all tests
afterEach(() => {
	vi.restoreAllMocks();
});

// Test data
const valid_paths = [
	'/allowed/path/file.txt',
	'/allowed/path/',
	'/allowed/path',
	'/allowed/deeper/nested/file.txt',
	// Add more cases
	'./allowed/file.txt', // Relative path
	'/allowed', // Just the directory name
];

const invalid_paths = [
	'/not_allowed/file.txt',
	'../allowed/path/file.txt',
	'/another/path/file.txt',
	'relative/path/file.txt',
	// Add more cases
	null as any,
	undefined as any,
	123 as any,
	{} as any,
	[] as any,
	true as any,
];

const allowed_dirs = [
	'/allowed/path/',
	'/allowed/deeper/',
	'/allowed/', // Parent directory that should match both above
	// Add more cases
	'./allowed/', // Relative path
];

const allowed_dirs_without_trailing_slash = [
	'/allowed/path',
	'/allowed/deeper',
	'/allowed',
	// Add more cases
	'./allowed', // Relative path
];

// Use these arrays in tests
const edge_case_paths = [
	'',
	'/',
	'.',
	'./',
	null as any,
	undefined as any,
	123 as any,
	{} as any,
	[] as any,
	true as any,
	false as any,
];

const edge_case_dirs = [
	'',
	'/',
	'.',
	'./',
	null as any,
	undefined as any,
	123 as any,
	{} as any,
	[] as any,
	true as any,
	false as any,
];

// is_path_in_allowed_dirs tests
test('is_path_in_allowed_dirs - should return true for paths in allowed directories', () => {
	for (const path of valid_paths) {
		for (const dirs of [allowed_dirs, allowed_dirs_without_trailing_slash]) {
			const result = is_path_in_allowed_dirs(path, dirs);
			expect(result).toBe(true);
		}
	}
});

test('is_path_in_allowed_dirs - should return false for paths not in allowed directories', () => {
	for (const path of invalid_paths) {
		const result = is_path_in_allowed_dirs(path, allowed_dirs);
		expect(result).toBe(false);
	}
});

test('is_path_in_allowed_dirs - should handle edge case paths', () => {
	for (const path of edge_case_paths) {
		const result = is_path_in_allowed_dirs(path, allowed_dirs);
		expect(result).toBe(false);
	}
});

test('is_path_in_allowed_dirs - should handle edge case directories', () => {
	// Empty directory should never match
	expect(is_path_in_allowed_dirs('/any/path', [''])).toBe(false);

	// Root directory should match any absolute path
	expect(is_path_in_allowed_dirs('/any/path', ['/'])).toBe(true);

	// Current directory behavior
	expect(is_path_in_allowed_dirs('./file.txt', ['.'])).toBe(false); // Won't match because ensure_end adds slash
	expect(is_path_in_allowed_dirs('./file.txt', ['./'])).toBe(true);

	// Other edge cases
	for (const dir of edge_case_dirs) {
		if (dir === '/') continue; // Skip root dir which has special behavior
		if (dir === './') continue; // Skip './' which has special behavior
		const result = is_path_in_allowed_dirs('/any/path', Array.isArray(dir) ? dir : [dir]);
		expect(result).toBe(false);
	}
});

test('is_path_in_allowed_dirs - should always add trailing slash to directories', () => {
	// Both versions of directories should work the same
	expect(is_path_in_allowed_dirs('/allowed/path/file.txt', ['/allowed/path'])).toBe(true);
	expect(is_path_in_allowed_dirs('/allowed/path/file.txt', ['/allowed/path/'])).toBe(true);
});

test('is_path_in_allowed_dirs - should handle type-unsafe inputs', () => {
	// Test with null and undefined using type casting
	expect(is_path_in_allowed_dirs(null as any, allowed_dirs)).toBe(false);
	expect(is_path_in_allowed_dirs(undefined as any, allowed_dirs)).toBe(false);
	expect(is_path_in_allowed_dirs('/valid/path', null as any)).toBe(false);
	expect(is_path_in_allowed_dirs('/valid/path', undefined as any)).toBe(false);

	// Test with numbers and objects
	expect(is_path_in_allowed_dirs(123 as any, allowed_dirs)).toBe(false);
	expect(is_path_in_allowed_dirs('/valid/path', [123] as any)).toBe(false);
	expect(is_path_in_allowed_dirs({} as any, allowed_dirs)).toBe(false);
});

// write_path_in_scope tests
test('write_path_in_scope - should write file when path is in allowed directory (single dir)', () => {
	const path = '/allowed/path/file.txt';
	const contents = 'test contents';
	const dir = '/allowed/path/';

	const result = write_path_in_scope(path, contents, dir);

	expect(result).toBe(true);
	expect(fs.writeFileSync).toHaveBeenCalledWith(path, contents, 'utf8');
	expect(fs.writeFileSync).toHaveBeenCalledTimes(1);
});

test('write_path_in_scope - should write file when path is in allowed directory (multiple dirs)', () => {
	const path = '/allowed/deeper/file.txt';
	const contents = 'test contents';
	const dirs = ['/allowed/path/', '/allowed/deeper/'];

	const result = write_path_in_scope(path, contents, dirs);

	expect(result).toBe(true);
	expect(fs.writeFileSync).toHaveBeenCalledWith(path, contents, 'utf8');
	expect(fs.writeFileSync).toHaveBeenCalledTimes(1);
});

test('write_path_in_scope - should not write file when path is outside allowed directory', () => {
	const path = '/not_allowed/file.txt';
	const contents = 'test contents';
	const dir = '/allowed/path/';

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	const result = write_path_in_scope(path, contents, dir);

	expect(result).toBe(false);
	expect(fs.writeFileSync).not.toHaveBeenCalled();

	console_spy.mockRestore();
});

test('write_path_in_scope - should handle various directory input formats', () => {
	const path = '/allowed/path/file.txt';
	const contents = 'test contents';

	// Test with and without trailing slash
	expect(write_path_in_scope(path, contents, '/allowed/path')).toBe(true);
	expect(write_path_in_scope(path, contents, '/allowed/path/')).toBe(true);

	// Array versions
	expect(write_path_in_scope(path, contents, ['/allowed/path'])).toBe(true);
	expect(write_path_in_scope(path, contents, ['/allowed/path/'])).toBe(true);
});

test('write_path_in_scope - should handle empty inputs', () => {
	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	// Empty path
	expect(write_path_in_scope('', 'contents', '/allowed/path/')).toBe(false);
	expect(fs.writeFileSync).not.toHaveBeenCalled();

	// Empty contents should still work
	expect(write_path_in_scope('/allowed/path/empty.txt', '', '/allowed/path/')).toBe(true);
	expect(fs.writeFileSync).toHaveBeenCalledWith('/allowed/path/empty.txt', '', 'utf8');

	// Empty directory
	expect(write_path_in_scope('/some/path/file.txt', 'contents', '')).toBe(false);

	console_spy.mockRestore();
});

test('write_path_in_scope - should handle type-unsafe inputs', () => {
	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	// Null and undefined
	expect(write_path_in_scope(null as any, 'contents', '/allowed/path/')).toBe(false);
	expect(write_path_in_scope('/allowed/path/file.txt', null as any, '/allowed/path/')).toBe(true); // Contents can be null
	expect(write_path_in_scope('/allowed/path/file.txt', 'contents', null as any)).toBe(false);

	// Numbers and objects
	expect(write_path_in_scope(123 as any, 'contents', '/allowed/path/')).toBe(false);
	expect(write_path_in_scope('/allowed/path/file.txt', 123 as any, '/allowed/path/')).toBe(true); // Contents can be number
	expect(write_path_in_scope('/allowed/path/file.txt', 'contents', 123 as any)).toBe(false);

	console_spy.mockRestore();
});

// delete_path_in_scope tests
test('delete_path_in_scope - should delete file when path is in allowed directory (single dir)', () => {
	const path = '/allowed/path/file.txt';
	const dir = '/allowed/path/';

	const result = delete_path_in_scope(path, dir);

	expect(result).toBe(true);
	expect(fs.rmSync).toHaveBeenCalledWith(path);
	expect(fs.rmSync).toHaveBeenCalledTimes(1);
});

test('delete_path_in_scope - should delete file when path is in allowed directory (multiple dirs)', () => {
	const path = '/allowed/deeper/file.txt';
	const dirs = ['/allowed/path/', '/allowed/deeper/'];

	const result = delete_path_in_scope(path, dirs);

	expect(result).toBe(true);
	expect(fs.rmSync).toHaveBeenCalledWith(path);
	expect(fs.rmSync).toHaveBeenCalledTimes(1);
});

test('delete_path_in_scope - should not delete file when path is outside allowed directory', () => {
	const path = '/not_allowed/file.txt';
	const dir = '/allowed/path/';

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	const result = delete_path_in_scope(path, dir);

	expect(result).toBe(false);
	expect(fs.rmSync).not.toHaveBeenCalled();

	console_spy.mockRestore();
});

test('delete_path_in_scope - should handle various directory input formats', () => {
	const path = '/allowed/path/file.txt';

	// Test with and without trailing slash
	expect(delete_path_in_scope(path, '/allowed/path')).toBe(true);
	expect(delete_path_in_scope(path, '/allowed/path/')).toBe(true);

	// Array versions
	expect(delete_path_in_scope(path, ['/allowed/path'])).toBe(true);
	expect(delete_path_in_scope(path, ['/allowed/path/'])).toBe(true);
});

test('delete_path_in_scope - should handle empty inputs', () => {
	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	// Empty path
	expect(delete_path_in_scope('', '/allowed/path/')).toBe(false);
	expect(fs.rmSync).not.toHaveBeenCalled();

	// Empty directory
	expect(delete_path_in_scope('/some/path/file.txt', '')).toBe(false);

	console_spy.mockRestore();
});

test('delete_path_in_scope - should handle type-unsafe inputs', () => {
	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	// Null and undefined
	expect(delete_path_in_scope(null as any, '/allowed/path/')).toBe(false);
	expect(delete_path_in_scope('/allowed/path/file.txt', null as any)).toBe(false);

	// Numbers and objects
	expect(delete_path_in_scope(123 as any, '/allowed/path/')).toBe(false);
	expect(delete_path_in_scope('/allowed/path/file.txt', 123 as any)).toBe(false);

	console_spy.mockRestore();
});

// Systematic combinatorial tests
test('Combined function behavior - systematic testing of path/dir combinations', () => {
	// Create arrays of test cases
	const test_paths = [
		'/allowed/path/file.txt',
		'/not_allowed/file.txt',
		'',
		null as any,
		undefined as any,
		123 as any,
		{} as any,
	];

	const test_contents = ['test content', '', null as any, undefined as any, 123 as any];

	const test_dirs = [
		'/allowed/path/',
		'/allowed/path',
		['/allowed/path/', '/allowed/deeper/'],
		'',
		null as any,
		undefined as any,
		123 as any,
		{} as any,
	];

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	// Test all combinations for write_path_in_scope
	for (const path of test_paths) {
		for (const content of test_contents) {
			for (const dir of test_dirs) {
				// Skip combinations known to cause errors
				if (
					(path === null || path === undefined || typeof path !== 'string') &&
					(dir === null || dir === undefined || (typeof dir !== 'string' && !Array.isArray(dir)))
				) {
					continue;
				}

				// Reset mocks
				vi.clearAllMocks();

				// Determine expected result using our is_path_in_allowed_dirs function.
				const valid_path = path && typeof path === 'string' && path !== '';
				const valid_dir = dir && (typeof dir === 'string' || Array.isArray(dir));
				const should_succeed = !!(
					valid_path &&
					valid_dir &&
					is_path_in_allowed_dirs(path, to_array(dir))
				);

				// Test write
				const write_result = write_path_in_scope(path, content, dir);
				expect(write_result).toBe(should_succeed);
				expect(fs.writeFileSync).toHaveBeenCalledTimes(should_succeed ? 1 : 0);

				// Test delete
				vi.clearAllMocks();
				const delete_result = delete_path_in_scope(path, dir);
				expect(delete_result).toBe(should_succeed);
				expect(fs.rmSync).toHaveBeenCalledTimes(should_succeed ? 1 : 0);
			}
		}
	}

	console_spy.mockRestore();
});

// Error handling tests
test('Function error handling - should handle filesystem errors gracefully', () => {
	// Setup filesystem errors
	vi.mocked(fs.writeFileSync).mockImplementationOnce(() => {
		throw new Error('Disk full');
	});

	vi.mocked(fs.rmSync).mockImplementationOnce(() => {
		throw new Error('File not found');
	});

	// Mock console.error to catch the error messages
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	// Test write function with error
	expect(() => {
		write_path_in_scope('/allowed/path/file.txt', 'content', '/allowed/path/');
	}).toThrow('Disk full');

	// Test delete function with error
	expect(() => {
		delete_path_in_scope('/allowed/path/file.txt', '/allowed/path/');
	}).toThrow('File not found');

	console_spy.mockRestore();
});
