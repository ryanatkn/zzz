import {test, expect, vi, beforeEach, afterEach, describe} from 'vitest';
import * as fs from 'node:fs/promises';
import * as fs_sync from 'node:fs';

import {Safe_Fs, Symlink_Not_Allowed_Error} from '$lib/server/safe_fs.js';

/* eslint-disable no-await-in-loop, @typescript-eslint/no-empty-function */

// Mock fs/promises and fs modules
vi.mock('node:fs/promises', () => ({
	readFile: vi.fn(),
	writeFile: vi.fn(),
	rm: vi.fn(),
	mkdir: vi.fn(),
	readdir: vi.fn(),
	stat: vi.fn(),
	lstat: vi.fn(),
	copyFile: vi.fn(),
	access: vi.fn(),
}));

vi.mock('node:fs', () => ({
	existsSync: vi.fn(),
}));

// Test constants
const TEST_ALLOWED_PATHS = ['/allowed/path', '/allowed/other/path/', '/another/allowed/directory'];
const FILE_PATHS = {
	ALLOWED: '/allowed/path/file.txt',
	NESTED: '/allowed/path/subdir/file.txt',
	OUTSIDE: '/not/allowed/file.txt',
	TRAVERSAL: '/allowed/path/../../../etc/passwd',
};
const DIR_PATHS = {
	ALLOWED: '/allowed/path/dir',
	OUTSIDE: '/not/allowed/dir',
	NEW_DIR: '/allowed/path/new-dir',
};

// Helper to create test instance
const create_test_instance = () => new Safe_Fs(TEST_ALLOWED_PATHS);

// Setup/cleanup for each test
let console_spy: any;

beforeEach(() => {
	vi.clearAllMocks();
	console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	// Default mock implementations
	vi.mocked(fs_sync.existsSync).mockReturnValue(true);

	// Default lstat mock returning a non-symlink file
	vi.mocked(fs.lstat).mockImplementation(() =>
		Promise.resolve({
			isSymbolicLink: () => false,
			isDirectory: () => false,
			isFile: () => true,
		} as any),
	);
});

afterEach(() => {
	console_spy.mockRestore();
});

describe('Safe_Fs - Construction and Initialization', () => {
	test('constructor - should accept an array of allowed paths', () => {
		const safe_fs = create_test_instance();
		expect(safe_fs).toBeInstanceOf(Safe_Fs);
	});

	test('constructor - should make a defensive copy of allowed paths', () => {
		const original_paths = [...TEST_ALLOWED_PATHS];
		const safe_fs = new Safe_Fs(original_paths);

		// Modifying the original array should not affect the instance
		original_paths.push('/new/path');

		// The instance should still only allow the original paths
		expect(safe_fs.is_path_allowed('/new/path')).toBe(false);
	});

	test('constructor - should throw for invalid paths', () => {
		// Non-absolute path
		expect(() => new Safe_Fs(['relative/path'])).toThrow();

		// Empty path array should work but won't allow any paths
		const empty_safe_fs = new Safe_Fs([]);
		expect(empty_safe_fs.is_path_allowed('/any/path')).toBe(false);
	});
});

describe('Safe_Fs - Path Validation', () => {
	test('is_path_allowed - should return true for paths within allowed directories', () => {
		const safe_fs = create_test_instance();

		const valid_paths = [
			...TEST_ALLOWED_PATHS,
			FILE_PATHS.ALLOWED,
			FILE_PATHS.NESTED,
			'/allowed/path/subdir/',
		];

		for (const path of valid_paths) {
			expect(safe_fs.is_path_allowed(path)).toBe(true);
		}
	});

	test('is_path_allowed - should return false for paths outside allowed directories', () => {
		const safe_fs = create_test_instance();

		const invalid_paths = [
			FILE_PATHS.OUTSIDE,
			DIR_PATHS.OUTSIDE,
			'/allowed', // parent of allowed path
			'/allowed-other', // similar prefix
		];

		for (const path of invalid_paths) {
			expect(safe_fs.is_path_allowed(path)).toBe(false);
		}
	});

	test('is_path_allowed - should reject relative paths', () => {
		const safe_fs = create_test_instance();

		const relative_paths = ['relative/path', './relative/path', '../relative/path'];

		for (const path of relative_paths) {
			expect(safe_fs.is_path_allowed(path)).toBe(false);
		}
	});

	test('is_path_allowed - should detect path traversal attempts', () => {
		const safe_fs = create_test_instance();

		const traversal_paths = [FILE_PATHS.TRAVERSAL, '/allowed/path/../not-allowed'];

		for (const path of traversal_paths) {
			expect(safe_fs.is_path_allowed(path)).toBe(false);
		}
	});

	test('is_path_allowed - should handle special cases correctly', () => {
		const safe_fs = create_test_instance();

		// Empty path
		expect(safe_fs.is_path_allowed('')).toBe(false);

		// Root directory (only allowed if explicitly included)
		expect(safe_fs.is_path_allowed('/')).toBe(false);

		// With root directory explicitly allowed
		const root_safe_fs = new Safe_Fs(['/']);
		expect(root_safe_fs.is_path_allowed('/')).toBe(true);
		expect(root_safe_fs.is_path_allowed('/any/path')).toBe(true);
	});

	test('is_path_safe - should verify path security including symlink checks', async () => {
		const safe_fs = create_test_instance();

		// Regular allowed path without symlinks
		expect(await safe_fs.is_path_safe(FILE_PATHS.ALLOWED)).toBe(true);

		// Path outside allowed directories
		expect(await safe_fs.is_path_safe(FILE_PATHS.OUTSIDE)).toBe(false);

		// Path with traversal
		expect(await safe_fs.is_path_safe(FILE_PATHS.TRAVERSAL)).toBe(false);

		// Mock a symlink to test rejection
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => true,
				isDirectory: () => false,
				isFile: () => false,
			} as any),
		);

		// Symlinked file should fail the safety check
		expect(await safe_fs.is_path_safe('/allowed/path/symlink')).toBe(false);
	});
});

describe('Safe_Fs - File Operations', () => {
	test('read_file - should read files in allowed paths', async () => {
		const safe_fs = create_test_instance();
		const test_content = 'test file content';

		vi.mocked(fs.readFile).mockResolvedValueOnce(test_content as any);

		const content = await safe_fs.read_file(FILE_PATHS.ALLOWED);
		expect(content).toBe(test_content);
		expect(fs.readFile).toHaveBeenCalledWith(FILE_PATHS.ALLOWED, 'utf8');
	});

	test('read_file - should throw for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.read_file(FILE_PATHS.OUTSIDE)).rejects.toThrow('Path is not allowed');
		expect(fs.readFile).not.toHaveBeenCalled();
	});

	test('write_file - should write to files in allowed paths', async () => {
		const safe_fs = create_test_instance();
		const test_content = 'test content to write';

		vi.mocked(fs.writeFile).mockResolvedValueOnce();

		await safe_fs.write_file(FILE_PATHS.ALLOWED, test_content);
		expect(fs.writeFile).toHaveBeenCalledWith(FILE_PATHS.ALLOWED, test_content, 'utf8');
	});

	test('write_file - should throw for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.write_file(FILE_PATHS.OUTSIDE, 'content')).rejects.toThrow(
			'Path is not allowed',
		);
		expect(fs.writeFile).not.toHaveBeenCalled();
	});
});

describe('Safe_Fs - Directory Operations', () => {
	test('mkdir - should create directories in allowed paths', async () => {
		const safe_fs = create_test_instance();

		vi.mocked(fs.mkdir).mockResolvedValueOnce(undefined);

		await safe_fs.mkdir(DIR_PATHS.NEW_DIR, {recursive: true});
		expect(fs.mkdir).toHaveBeenCalledWith(DIR_PATHS.NEW_DIR, {recursive: true});
	});

	test('mkdir - should throw for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.mkdir(DIR_PATHS.OUTSIDE)).rejects.toThrow('Path is not allowed');
		expect(fs.mkdir).not.toHaveBeenCalled();
	});

	test('readdir - should list directory contents in allowed paths', async () => {
		const safe_fs = create_test_instance();
		const dir_contents = ['file1.txt', 'file2.txt', 'subdir'];

		vi.mocked(fs.readdir).mockResolvedValueOnce(dir_contents as any);

		const contents = await safe_fs.readdir(DIR_PATHS.ALLOWED, null);
		expect(contents).toEqual(dir_contents);
		expect(fs.readdir).toHaveBeenCalledWith(DIR_PATHS.ALLOWED, null);
	});

	test('readdir - should throw for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.readdir(DIR_PATHS.OUTSIDE)).rejects.toThrow('Path is not allowed');
		expect(fs.readdir).not.toHaveBeenCalled();
	});

	test('rm - should remove files or directories in allowed paths', async () => {
		const safe_fs = create_test_instance();

		vi.mocked(fs.rm).mockResolvedValueOnce();

		await safe_fs.rm(DIR_PATHS.ALLOWED, {recursive: true});
		expect(fs.rm).toHaveBeenCalledWith(DIR_PATHS.ALLOWED, {recursive: true});
	});

	test('rm - should throw for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.rm(DIR_PATHS.OUTSIDE)).rejects.toThrow('Path is not allowed');
		expect(fs.rm).not.toHaveBeenCalled();
	});
});

describe('Safe_Fs - Stat Operations', () => {
	test('stat - should get stats for paths in allowed directories', async () => {
		const safe_fs = create_test_instance();
		const mock_stats = {
			isFile: () => true,
			isDirectory: () => false,
		} as fs_sync.Stats;

		vi.mocked(fs.stat).mockResolvedValueOnce(mock_stats);

		const stats = await safe_fs.stat(FILE_PATHS.ALLOWED);
		expect(stats).toBe(mock_stats);
		expect(fs.stat).toHaveBeenCalledWith(FILE_PATHS.ALLOWED, undefined);
	});

	test('stat - should throw for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.stat(FILE_PATHS.OUTSIDE)).rejects.toThrow('Path is not allowed');
		expect(fs.stat).not.toHaveBeenCalled();
	});

	test('stat - should handle bigint option correctly', async () => {
		const safe_fs = create_test_instance();

		const stats_tests = [
			{options: undefined, expected_options: undefined},
			{options: {bigint: false}, expected_options: {bigint: false}},
			{options: {bigint: true}, expected_options: {bigint: true}},
		];

		for (const {options, expected_options} of stats_tests) {
			vi.mocked(fs.stat).mockReset();
			vi.mocked(fs.stat).mockResolvedValueOnce({} as any);

			await safe_fs.stat(FILE_PATHS.ALLOWED, options as any);
			expect(fs.stat).toHaveBeenCalledWith(FILE_PATHS.ALLOWED, expected_options);
		}
	});
});

describe('Safe_Fs - Existence Checking', () => {
	test('exists - should check existence for paths in allowed directories', async () => {
		const safe_fs = create_test_instance();

		const existence_tests = [
			{mock_fn: () => vi.mocked(fs.access).mockResolvedValueOnce(), expected: true},
			{
				mock_fn: () => vi.mocked(fs.access).mockRejectedValueOnce(new Error('ENOENT')),
				expected: false,
			},
		];

		for (const {mock_fn, expected} of existence_tests) {
			mock_fn();
			const exists = await safe_fs.exists(FILE_PATHS.ALLOWED);
			expect(exists).toBe(expected);
		}
	});

	test('exists - should return false for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		const exists = await safe_fs.exists(FILE_PATHS.OUTSIDE);
		expect(exists).toBe(false);
		expect(fs.access).not.toHaveBeenCalled();
	});
});

describe('Safe_Fs - Copy Operations', () => {
	test('copy_file - should copy files between allowed paths', async () => {
		const safe_fs = create_test_instance();
		const source = FILE_PATHS.ALLOWED;
		const destination = '/allowed/path/destination.txt';

		vi.mocked(fs.copyFile).mockResolvedValueOnce();

		await safe_fs.copy_file(source, destination);
		expect(fs.copyFile).toHaveBeenCalledWith(source, destination, undefined);
	});

	test('copy_file - should throw if either source or destination is outside allowed paths', async () => {
		const safe_fs = create_test_instance();
		const invalid_copy_operations = [
			{source: FILE_PATHS.OUTSIDE, destination: FILE_PATHS.ALLOWED},
			{source: FILE_PATHS.ALLOWED, destination: FILE_PATHS.OUTSIDE},
		];

		for (const {source, destination} of invalid_copy_operations) {
			await expect(safe_fs.copy_file(source, destination)).rejects.toThrow('Path is not allowed');
		}

		expect(fs.copyFile).not.toHaveBeenCalled();
	});
});

describe('Safe_Fs - Symlink Detection', () => {
	test('should reject operations on paths containing symlinks', async () => {
		const safe_fs = create_test_instance();

		// Make the file path appear as a symlink
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => true,
				isDirectory: () => false,
				isFile: () => false,
			} as any),
		);

		await expect(safe_fs.read_file('/allowed/path/symlink.txt')).rejects.toThrow(
			Symlink_Not_Allowed_Error,
		);

		expect(fs.readFile).not.toHaveBeenCalled();
	});

	test('should reject operations when parent directory is a symlink', async () => {
		const safe_fs = create_test_instance();

		// First check on file itself - not a symlink
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => false,
				isDirectory: () => false,
				isFile: () => true,
			} as any),
		);

		// Then check on parent - is a symlink
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => true,
				isDirectory: () => true,
				isFile: () => false,
			} as any),
		);

		await expect(safe_fs.read_file('/allowed/path/symlink-dir/file.txt')).rejects.toThrow(
			Symlink_Not_Allowed_Error,
		);

		expect(fs.readFile).not.toHaveBeenCalled();
	});
});
