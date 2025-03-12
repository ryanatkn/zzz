import {test, expect, vi, beforeEach, afterEach} from 'vitest';
import * as fs from 'node:fs';
import {to_array} from '@ryanatkn/belt/array.js';
import * as path from 'node:path';

import {
	find_matching_allowed_dir,
	write_to_allowed_dir,
	delete_from_allowed_dir,
	is_symlink,
	has_traversal_segments,
} from '$lib/server/filesystem_helpers.js';

/* eslint-disable @typescript-eslint/no-empty-function */

// Mock filesystem functions to prevent actual file operations
vi.mock('node:fs', () => ({
	writeFileSync: vi.fn(),
	rmSync: vi.fn(),
	lstatSync: vi.fn(),
	existsSync: vi.fn(),
}));

// Reset mocks before each test
beforeEach(() => {
	vi.clearAllMocks();
	vi.mocked(fs.existsSync).mockReturnValue(true); // default to paths existing
	vi.mocked(fs.lstatSync).mockReturnValue({
		isSymbolicLink: () => false,
	} as any);
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
	'./allowed/file.txt',
	'/allowed',
];

const invalid_paths = [
	'/not_allowed/file.txt',
	'../allowed/path/file.txt',
	'/another/path/file.txt',
	'relative/path/file.txt',
	null as any,
	undefined as any,
	123 as any,
	{} as any,
	[] as any,
	true as any,
];

const allowed_dirs = ['/allowed/path/', '/allowed/deeper/', '/allowed/', './allowed/'];

const allowed_dirs_without_trailing_slash = [
	'/allowed/path',
	'/allowed/deeper',
	'/allowed',
	'./allowed',
];

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

// find_matching_allowed_dir tests
test('find_matching_allowed_dir - should return matching dir for paths in allowed directories', () => {
	for (const p of valid_paths) {
		for (const dirs of [allowed_dirs, allowed_dirs_without_trailing_slash]) {
			const result = find_matching_allowed_dir(p, dirs);
			expect(result).not.toBeNull();
			// Verify it returned one of the dirs
			expect(dirs.includes(result as any)).toBe(true);
		}
	}
});

test('find_matching_allowed_dir - should return null for paths not in allowed directories', () => {
	for (const p of invalid_paths) {
		const result = find_matching_allowed_dir(p, allowed_dirs);
		expect(result).toBeNull();
	}
});

test('find_matching_allowed_dir - should handle edge case paths', () => {
	for (const p of edge_case_paths) {
		const result = find_matching_allowed_dir(p, allowed_dirs);
		expect(result).toBeNull();
	}
});

test('find_matching_allowed_dir - should handle edge case directories', () => {
	// Empty directory should never match
	expect(find_matching_allowed_dir('/any/path', [''])).toBeNull();

	// Root directory should match any absolute path
	expect(find_matching_allowed_dir('/any/path', ['/'])).toBe('/');

	// Current directory behavior
	expect(find_matching_allowed_dir('./file.txt', ['.'])).toBeNull(); // Explicitly denied in implementation
	expect(find_matching_allowed_dir('./file.txt', ['./'])).toBe('./');

	// Other edge cases
	for (const dir of edge_case_dirs) {
		if (dir === '/') continue; // Skip root dir which has special behavior
		if (dir === './') continue; // Skip './' which has special behavior
		const result = find_matching_allowed_dir('/any/path', Array.isArray(dir) ? dir : [dir]);
		expect(result).toBeNull();
	}
});

test('find_matching_allowed_dir - should handle type-unsafe inputs', () => {
	// Test with null and undefined using type casting
	expect(find_matching_allowed_dir(null as any, allowed_dirs)).toBeNull();
	expect(find_matching_allowed_dir(undefined as any, allowed_dirs)).toBeNull();
	expect(find_matching_allowed_dir('/valid/path', null as any)).toBeNull();
	expect(find_matching_allowed_dir('/valid/path', undefined as any)).toBeNull();

	// Test with numbers and objects
	expect(find_matching_allowed_dir(123 as any, allowed_dirs)).toBeNull();
	expect(find_matching_allowed_dir('/valid/path', [123] as any)).toBeNull();
	expect(find_matching_allowed_dir({} as any, allowed_dirs)).toBeNull();
});

// Test for path traversal protection without mocking path
test('find_matching_allowed_dir - should prevent path traversal attacks', () => {
	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	// We need to directly test the paths that would be used in attacks
	// without relying on path.resolve's behavior
	expect(find_matching_allowed_dir('/allowed/path/../outside/file.txt', ['/allowed'])).toBeNull();
	expect(find_matching_allowed_dir('/allowed/path/../../etc/passwd', ['/allowed/path'])).toBeNull();
	expect(find_matching_allowed_dir('/allowed/path/../path/file.txt', ['/allowed'])).toBeNull();

	console_spy.mockRestore();
});

// Test cross-platform behavior
test('find_matching_allowed_dir - should handle platform-specific path features', () => {
	// Note: This test makes assertions based on whether we're running on Windows or Unix
	// Testing Windows-style paths on Unix systems will still use Unix resolution
	const isWindows = process.platform === 'win32';

	// For Windows, test backslash paths, drive letters
	if (isWindows) {
		expect(find_matching_allowed_dir('C:\\Windows', ['C:\\'])).toBe('C:\\');
		expect(find_matching_allowed_dir('C:\\Windows\\System32', ['C:\\Windows'])).toBe('C:\\Windows');
		expect(find_matching_allowed_dir('C:\\Program Files', ['C:\\Windows'])).toBeNull();
	} else {
		// On Unix, test Unix-specific features
		expect(find_matching_allowed_dir('/usr/bin', ['/usr'])).toBe('/usr');
		expect(find_matching_allowed_dir('/usr/local/bin', ['/usr/local'])).toBe('/usr/local');
		expect(find_matching_allowed_dir('/var/log', ['/usr'])).toBeNull();
	}
});

// Test that the first matching directory is returned
test('find_matching_allowed_dir - should return the first matching directory', () => {
	// Create a list of directories with overlapping scopes
	const overlapping_dirs = ['/allowed/path/specific/', '/allowed/path/', '/allowed/'];

	// A path that matches multiple directories should return the first one
	const result = find_matching_allowed_dir('/allowed/path/specific/file.txt', overlapping_dirs);
	expect(result).toBe('/allowed/path/specific/');
});

// write_to_allowed_dir tests
test('write_to_allowed_dir - should write file when path is in allowed directory (single dir)', () => {
	const path = '/allowed/path/file.txt';
	const contents = 'test contents';
	const dir = '/allowed/path/';

	const result = write_to_allowed_dir(path, contents, dir);

	expect(result).toBe(true);
	expect(fs.writeFileSync).toHaveBeenCalledWith(path, contents, 'utf8');
	expect(fs.writeFileSync).toHaveBeenCalledTimes(1);
});

test('write_to_allowed_dir - should write file when path is in allowed directory (multiple dirs)', () => {
	const path = '/allowed/deeper/file.txt';
	const contents = 'test contents';
	const dirs = ['/allowed/path/', '/allowed/deeper/'];

	const result = write_to_allowed_dir(path, contents, dirs);

	expect(result).toBe(true);
	expect(fs.writeFileSync).toHaveBeenCalledWith(path, contents, 'utf8');
	expect(fs.writeFileSync).toHaveBeenCalledTimes(1);
});

test('write_to_allowed_dir - should not write file when path is outside allowed directory', () => {
	const path = '/not_allowed/file.txt';
	const contents = 'test contents';
	const dir = '/allowed/path/';

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	const result = write_to_allowed_dir(path, contents, dir);

	expect(result).toBe(false);
	expect(fs.writeFileSync).not.toHaveBeenCalled();

	console_spy.mockRestore();
});

test('write_to_allowed_dir - should handle various directory input formats', () => {
	const path = '/allowed/path/file.txt';
	const contents = 'test contents';

	// Test with and without trailing slash
	expect(write_to_allowed_dir(path, contents, '/allowed/path')).toBe(true);
	expect(write_to_allowed_dir(path, contents, '/allowed/path/')).toBe(true);

	// Array versions
	expect(write_to_allowed_dir(path, contents, ['/allowed/path'])).toBe(true);
	expect(write_to_allowed_dir(path, contents, ['/allowed/path/'])).toBe(true);
});

test('write_to_allowed_dir - should handle empty inputs', () => {
	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	// Empty path
	expect(write_to_allowed_dir('', 'contents', '/allowed/path/')).toBe(false);
	expect(fs.writeFileSync).not.toHaveBeenCalled();

	// Empty contents should still work
	expect(write_to_allowed_dir('/allowed/path/empty.txt', '', '/allowed/path/')).toBe(true);
	expect(fs.writeFileSync).toHaveBeenCalledWith('/allowed/path/empty.txt', '', 'utf8');

	// Empty directory
	expect(write_to_allowed_dir('/some/path/file.txt', 'contents', '')).toBe(false);

	console_spy.mockRestore();
});

test('write_to_allowed_dir - should handle type-unsafe inputs', () => {
	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	// Null and undefined
	expect(write_to_allowed_dir(null as any, 'contents', '/allowed/path/')).toBe(false);
	expect(write_to_allowed_dir('/allowed/path/file.txt', null as any, '/allowed/path/')).toBe(true); // Contents can be null
	expect(write_to_allowed_dir('/allowed/path/file.txt', 'contents', null as any)).toBe(false);

	// Numbers and objects
	expect(write_to_allowed_dir(123 as any, 'contents', '/allowed/path/')).toBe(false);
	expect(write_to_allowed_dir('/allowed/path/file.txt', 123 as any, '/allowed/path/')).toBe(true); // Contents can be number
	expect(write_to_allowed_dir('/allowed/path/file.txt', 'contents', 123 as any)).toBe(false);

	console_spy.mockRestore();
});

// Test for path traversal protection with write_to_allowed_dir
test('write_to_allowed_dir - should prevent path traversal attacks', () => {
	// Test with a path that resolves outside the allowed directory
	const path_with_traversal = '/allowed/path/../../../etc/passwd';
	const contents = 'malicious content';
	const dir = '/allowed/path/';

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	const result = write_to_allowed_dir(path_with_traversal, contents, dir);

	expect(result).toBe(false);
	expect(fs.writeFileSync).not.toHaveBeenCalled();

	console_spy.mockRestore();
});

// delete_from_allowed_dir tests
test('delete_from_allowed_dir - should delete file when path is in allowed directory (single dir)', () => {
	const path = '/allowed/path/file.txt';
	const dir = '/allowed/path/';

	const result = delete_from_allowed_dir(path, dir);

	expect(result).toBe(true);
	expect(fs.rmSync).toHaveBeenCalledWith(path);
	expect(fs.rmSync).toHaveBeenCalledTimes(1);
});

test('delete_from_allowed_dir - should delete file when path is in allowed directory (multiple dirs)', () => {
	const path = '/allowed/deeper/file.txt';
	const dirs = ['/allowed/path/', '/allowed/deeper/'];

	const result = delete_from_allowed_dir(path, dirs);

	expect(result).toBe(true);
	expect(fs.rmSync).toHaveBeenCalledWith(path);
	expect(fs.rmSync).toHaveBeenCalledTimes(1);
});

test('delete_from_allowed_dir - should not delete file when path is outside allowed directory', () => {
	const path = '/not_allowed/file.txt';
	const dir = '/allowed/path/';

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	const result = delete_from_allowed_dir(path, dir);

	expect(result).toBe(false);
	expect(fs.rmSync).not.toHaveBeenCalled();

	console_spy.mockRestore();
});

test('delete_from_allowed_dir - should handle various directory input formats', () => {
	const path = '/allowed/path/file.txt';

	// Test with and without trailing slash
	expect(delete_from_allowed_dir(path, '/allowed/path')).toBe(true);
	expect(delete_from_allowed_dir(path, '/allowed/path/')).toBe(true);

	// Array versions
	expect(delete_from_allowed_dir(path, ['/allowed/path'])).toBe(true);
	expect(delete_from_allowed_dir(path, ['/allowed/path/'])).toBe(true);
});

test('delete_from_allowed_dir - should handle empty inputs', () => {
	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	// Empty path
	expect(delete_from_allowed_dir('', '/allowed/path/')).toBe(false);
	expect(fs.rmSync).not.toHaveBeenCalled();

	// Empty directory
	expect(delete_from_allowed_dir('/some/path/file.txt', '')).toBe(false);

	console_spy.mockRestore();
});

test('delete_from_allowed_dir - should handle type-unsafe inputs', () => {
	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	// Null and undefined
	expect(delete_from_allowed_dir(null as any, '/allowed/path/')).toBe(false);
	expect(delete_from_allowed_dir('/allowed/path/file.txt', null as any)).toBe(false);

	// Numbers and objects
	expect(delete_from_allowed_dir(123 as any, '/allowed/path/')).toBe(false);
	expect(delete_from_allowed_dir('/allowed/path/file.txt', 123 as any)).toBe(false);

	console_spy.mockRestore();
});

// Same for delete_from_allowed_dir
test('delete_from_allowed_dir - should prevent path traversal attacks', () => {
	// Test with a path that resolves outside the allowed directory
	const path_with_traversal = '/allowed/path/../../../etc/passwd';
	const dir = '/allowed/path/';

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	const result = delete_from_allowed_dir(path_with_traversal, dir);

	expect(result).toBe(false);
	expect(fs.rmSync).not.toHaveBeenCalled();

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

	// Test all combinations for write_to_allowed_dir
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

				// Determine expected result using our find_matching_allowed_dir function.
				const valid_path = path && typeof path === 'string' && path !== '';
				const valid_dir = dir && (typeof dir === 'string' || Array.isArray(dir));
				const matching_dir =
					valid_path && valid_dir ? find_matching_allowed_dir(path, to_array(dir)) : null;
				const should_succeed = !!matching_dir;

				// Test write
				const write_result = write_to_allowed_dir(path, content, dir);
				expect(write_result).toBe(should_succeed);
				expect(fs.writeFileSync).toHaveBeenCalledTimes(should_succeed ? 1 : 0);

				// Test delete
				vi.clearAllMocks();
				const delete_result = delete_from_allowed_dir(path, dir);
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

	// Test write function with error - expect false return instead of throw
	const write_result = write_to_allowed_dir('/allowed/path/file.txt', 'content', '/allowed/path/');
	expect(write_result).toBe(false);

	// Test delete function with error - expect false return instead of throw
	const delete_result = delete_from_allowed_dir('/allowed/path/file.txt', '/allowed/path/');
	expect(delete_result).toBe(false);

	console_spy.mockRestore();
});

// Test for unicode and special character handling
test('find_matching_allowed_dir - should handle unicode and special characters', () => {
	// These paths are constructed to test if the implementation correctly handles special characters
	// but doesn't depend on mocking path.resolve
	const special_path_tests = [
		{
			path: path.join('/allowed/path', 'file with spaces.txt'),
			allowed_in: ['/allowed/path'],
			expected: '/allowed/path',
		},
		{
			path: path.join('/allowed/path', 'file_with_!@#$%^&*().txt'),
			allowed_in: ['/allowed/path'],
			expected: '/allowed/path',
		},
		// Unicode paths test (ensure implementation handles non-ASCII characters)
		// Note: The exact behavior might differ by OS
		{
			path: path.join('/allowed/path', 'файл.txt'),
			allowed_in: ['/allowed/path'],
			expected: '/allowed/path',
		},
	];

	for (const test_case of special_path_tests) {
		const result = find_matching_allowed_dir(test_case.path, test_case.allowed_in);
		expect(result).toBe(test_case.expected);
	}
});

// Test segment-based directory traversal detection
test('has_traversal_segments - should detect directory traversal segments', () => {
	// Paths with traversal segments
	const paths_with_traversal = [
		'../file.txt',
		'/allowed/../file.txt',
		'/allowed/path/../../etc/passwd',
	];

	for (const p of paths_with_traversal) {
		const result = has_traversal_segments(p);
		expect(result).toBe(true);
	}

	// Valid paths that contain '..' but not as segments
	const paths_without_traversal = [
		'/allowed/path/file..txt',
		'/allowed/path/my..file.bak',
		'/allowed/path/file.with...dots.txt',
	];

	for (const p of paths_without_traversal) {
		expect(has_traversal_segments(p)).toBe(false);
	}
});

// Test symlink detection
test('is_symlink - should detect symbolic links', () => {
	// Mock symlink detection
	vi.mocked(fs.lstatSync).mockReturnValueOnce({
		isSymbolicLink: () => true,
	} as any);

	expect(is_symlink('/allowed/path/symlink')).toBe(true);

	// Non-symlink
	vi.mocked(fs.lstatSync).mockReturnValueOnce({
		isSymbolicLink: () => false,
	} as any);

	expect(is_symlink('/allowed/path/regular-file')).toBe(false);

	// Non-existent path
	vi.mocked(fs.existsSync).mockReturnValueOnce(false);
	expect(is_symlink('/allowed/path/nonexistent')).toBe(false);
});

// Test symlink handling in find_matching_allowed_dir
test('find_matching_allowed_dir - should reject symlinks', () => {
	// Mock path as symlink
	vi.mocked(fs.lstatSync).mockReturnValueOnce({
		isSymbolicLink: () => true,
	} as any);

	expect(find_matching_allowed_dir('/allowed/path/symlink', ['/allowed/path'])).toBeNull();

	// Mock parent directory as symlink
	vi.mocked(fs.existsSync).mockImplementation(() => true);
	vi.mocked(fs.lstatSync)
		.mockImplementationOnce(
			() =>
				({
					isSymbolicLink: () => false,
				}) as any,
		)
		.mockImplementationOnce(
			() =>
				({
					isSymbolicLink: () => true,
				}) as any,
		);

	expect(find_matching_allowed_dir('/allowed/symlink-dir/file.txt', ['/allowed'])).toBeNull();
});

// Test path resolution and comparison
test('find_matching_allowed_dir - should use path resolution for comparison', () => {
	// Set up tests where resolved path will be in allowed dir
	vi.mocked(fs.existsSync).mockImplementation(() => true);
	vi.mocked(fs.lstatSync).mockImplementation(
		() =>
			({
				isSymbolicLink: () => false,
			}) as any,
	);

	// Test with redundant slashes and dot segments that normalize away
	expect(find_matching_allowed_dir('/allowed/path//./file.txt', ['/allowed/path'])).toBe(
		'/allowed/path',
	);
});

// Test that filenames containing '..' are allowed if they're not traversal
test('find_matching_allowed_dir - should allow filenames with dots', () => {
	vi.mocked(fs.existsSync).mockImplementation(() => true);
	vi.mocked(fs.lstatSync).mockImplementation(
		() =>
			({
				isSymbolicLink: () => false,
			}) as any,
	);

	expect(find_matching_allowed_dir('/allowed/path/file..txt', ['/allowed/path'])).toBe(
		'/allowed/path',
	);
	expect(find_matching_allowed_dir('/allowed/path/file.with...dots.txt', ['/allowed/path'])).toBe(
		'/allowed/path',
	);
	expect(find_matching_allowed_dir('/allowed/path/file...', ['/allowed/path'])).toBe(
		'/allowed/path',
	);
});

// Test with unusual filenames
test('find_matching_allowed_dir - should handle unusual filenames', () => {
	vi.mocked(fs.existsSync).mockImplementation(() => true);
	vi.mocked(fs.lstatSync).mockImplementation(
		() =>
			({
				isSymbolicLink: () => false,
			}) as any,
	);

	// Test with spaces, special chars, and Unicode
	const unusual_paths = [
		'/allowed/path/file with spaces.txt',
		'/allowed/path/file_with_!@#$%^&*().txt',
		'/allowed/path/файл.txt', // Cyrillic
		'/allowed/path/🔥.txt', // Emoji
		'/allowed/path/\u0000file.txt', // Null character (might not be valid on all filesystems)
	];

	for (const p of unusual_paths) {
		expect(find_matching_allowed_dir(p, ['/allowed/path'])).toBe('/allowed/path');
	}
});

// Test write_to_allowed_dir with symlinks
test('write_to_allowed_dir - should not write to symlinks', () => {
	// Mock path as symlink
	vi.mocked(fs.existsSync).mockReturnValue(true);
	vi.mocked(fs.lstatSync).mockReturnValueOnce({
		isSymbolicLink: () => true,
	} as any);

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	const result = write_to_allowed_dir('/allowed/path/symlink', 'content', '/allowed/path');

	expect(result).toBe(false);
	expect(fs.writeFileSync).not.toHaveBeenCalled();

	console_spy.mockRestore();
});

// Test delete_from_allowed_dir with symlinks
test('delete_from_allowed_dir - should not delete symlinks', () => {
	// Mock path as symlink
	vi.mocked(fs.existsSync).mockReturnValue(true);
	vi.mocked(fs.lstatSync).mockReturnValueOnce({
		isSymbolicLink: () => true,
	} as any);

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	const result = delete_from_allowed_dir('/allowed/path/symlink', '/allowed/path');

	expect(result).toBe(false);
	expect(fs.rmSync).not.toHaveBeenCalled();

	console_spy.mockRestore();
});
