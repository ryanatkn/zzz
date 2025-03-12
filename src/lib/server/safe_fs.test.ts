import {test, expect, vi, beforeEach, afterEach, describe} from 'vitest';
import * as fs from 'node:fs/promises';
import * as fs_sync from 'node:fs';

import {Safe_Fs, Path_Not_Allowed_Error, Symlink_Not_Allowed_Error} from '$lib/server/safe_fs.js';

/* eslint-disable @typescript-eslint/no-empty-function */

// Mock fs/promises and fs modules
vi.mock('node:fs/promises', () => ({
	readFile: vi.fn(),
	writeFile: vi.fn(),
	unlink: vi.fn(),
	rm: vi.fn(),
	mkdir: vi.fn(),
	rmdir: vi.fn(),
	readdir: vi.fn(),
	stat: vi.fn(),
	lstat: vi.fn(),
	copyFile: vi.fn(),
	access: vi.fn(),
}));

vi.mock('node:fs', () => ({
	existsSync: vi.fn(),
}));

// Test data
const test_allowed_paths = ['/allowed/path', '/allowed/other/path/', '/another/allowed/directory'];

// Error spy to avoid cluttering test output
let console_spy: any;

beforeEach(() => {
	vi.clearAllMocks();
	console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	// Default mocks for existsSync and lstat
	vi.mocked(fs_sync.existsSync).mockReturnValue(true);
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

// Helper function to create a test instance
const create_test_instance = () => {
	return new Safe_Fs(test_allowed_paths);
};

describe('Safe_Fs - Construction and Initialization', () => {
	test('constructor - should accept an array of allowed paths', () => {
		const safe_fs = create_test_instance();
		expect(safe_fs).toBeInstanceOf(Safe_Fs);
	});

	test('constructor - should make a defensive copy of allowed paths', () => {
		const original_paths = [...test_allowed_paths];
		const safe_fs = new Safe_Fs(original_paths);

		// Modifying the original array should not affect the instance
		original_paths.push('/new/path');

		// The instance should still only allow the original paths
		expect(safe_fs.is_path_allowed('/new/path')).toBe(false);
	});
});

describe('Safe_Fs - Path Validation', () => {
	test('is_path_allowed - should return true for paths within allowed directories', () => {
		const safe_fs = create_test_instance();

		// Test exact path matches
		expect(safe_fs.is_path_allowed('/allowed/path')).toBe(true);
		expect(safe_fs.is_path_allowed('/allowed/other/path/')).toBe(true);

		// Test subdirectories and files
		expect(safe_fs.is_path_allowed('/allowed/path/file.txt')).toBe(true);
		expect(safe_fs.is_path_allowed('/allowed/path/subdir/')).toBe(true);
		expect(safe_fs.is_path_allowed('/allowed/path/subdir/file.txt')).toBe(true);
	});

	test('is_path_allowed - should return false for paths outside allowed directories', () => {
		const safe_fs = create_test_instance();

		expect(safe_fs.is_path_allowed('/not/allowed/path')).toBe(false);
		expect(safe_fs.is_path_allowed('/allowed')).toBe(false); // parent of allowed path
		expect(safe_fs.is_path_allowed('/allowed-other')).toBe(false); // similar prefix
	});

	test('is_path_allowed - should reject relative paths', () => {
		const safe_fs = create_test_instance();

		expect(safe_fs.is_path_allowed('relative/path')).toBe(false);
		expect(safe_fs.is_path_allowed('./relative/path')).toBe(false);
		expect(safe_fs.is_path_allowed('../relative/path')).toBe(false);
	});

	test('is_path_allowed - should detect path traversal attempts', () => {
		const safe_fs = create_test_instance();

		expect(safe_fs.is_path_allowed('/allowed/path/../../../etc/passwd')).toBe(false);
		expect(safe_fs.is_path_allowed('/allowed/path/../not-allowed')).toBe(false);
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
});

describe('Safe_Fs - File Operations', () => {
	test('read_file - should read files in allowed paths', async () => {
		const safe_fs = create_test_instance();
		const test_content = 'test file content';

		vi.mocked(fs.readFile).mockResolvedValueOnce(test_content as any);

		const content = await safe_fs.read_file('/allowed/path/file.txt');
		expect(content).toBe(test_content);
		expect(fs.readFile).toHaveBeenCalledWith('/allowed/path/file.txt', undefined);
	});

	test('read_file - should throw for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.read_file('/not/allowed/file.txt')).rejects.toThrow('Path is not allowed');
		expect(fs.readFile).not.toHaveBeenCalled();
	});

	test('write_file - should write to files in allowed paths', async () => {
		const safe_fs = create_test_instance();
		const test_content = 'test content to write';

		vi.mocked(fs.writeFile).mockResolvedValueOnce();

		await safe_fs.write_file('/allowed/path/new-file.txt', test_content);
		expect(fs.writeFile).toHaveBeenCalledWith('/allowed/path/new-file.txt', test_content, null);
	});

	test('write_file - should throw for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.write_file('/not/allowed/file.txt', 'content')).rejects.toThrow(
			'Path is not allowed',
		);
		expect(fs.writeFile).not.toHaveBeenCalled();
	});

	test('unlink - should delete files in allowed paths', async () => {
		const safe_fs = create_test_instance();

		vi.mocked(fs.unlink).mockResolvedValueOnce();

		await safe_fs.unlink('/allowed/path/delete-file.txt');
		expect(fs.unlink).toHaveBeenCalledWith('/allowed/path/delete-file.txt');
	});

	test('unlink - should throw for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.unlink('/not/allowed/file.txt')).rejects.toThrow('Path is not allowed');
		expect(fs.unlink).not.toHaveBeenCalled();
	});

	test('copyFile - should copy files between allowed paths', async () => {
		const safe_fs = create_test_instance();

		vi.mocked(fs.copyFile).mockResolvedValueOnce();

		await safe_fs.copyFile('/allowed/path/source.txt', '/allowed/path/dest.txt');
		expect(fs.copyFile).toHaveBeenCalledWith(
			'/allowed/path/source.txt',
			'/allowed/path/dest.txt',
			undefined,
		);
	});

	test('copyFile - should throw if either source or destination is outside allowed paths', async () => {
		const safe_fs = create_test_instance();

		// Source outside allowed paths
		await expect(
			safe_fs.copyFile('/not/allowed/source.txt', '/allowed/path/dest.txt'),
		).rejects.toThrow('Path is not allowed');

		// Destination outside allowed paths
		await expect(
			safe_fs.copyFile('/allowed/path/source.txt', '/not/allowed/dest.txt'),
		).rejects.toThrow('Path is not allowed');

		expect(fs.copyFile).not.toHaveBeenCalled();
	});
});

describe('Safe_Fs - Directory Operations', () => {
	test('mkdir - should create directories in allowed paths', async () => {
		const safe_fs = create_test_instance();

		vi.mocked(fs.mkdir).mockResolvedValueOnce(undefined);

		await safe_fs.mkdir('/allowed/path/new-dir', {recursive: true});
		expect(fs.mkdir).toHaveBeenCalledWith('/allowed/path/new-dir', {recursive: true});
	});

	test('mkdir - should throw for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.mkdir('/not/allowed/dir')).rejects.toThrow('Path is not allowed');
		expect(fs.mkdir).not.toHaveBeenCalled();
	});

	test('rmdir - should remove empty directories in allowed paths', async () => {
		const safe_fs = create_test_instance();

		vi.mocked(fs.rmdir).mockResolvedValueOnce();

		await safe_fs.rmdir('/allowed/path/empty-dir');
		expect(fs.rmdir).toHaveBeenCalledWith('/allowed/path/empty-dir', undefined);
	});

	test('rmdir - should throw for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.rmdir('/not/allowed/dir')).rejects.toThrow('Path is not allowed');
		expect(fs.rmdir).not.toHaveBeenCalled();
	});

	test('readdir - should list directory contents in allowed paths', async () => {
		const safe_fs = create_test_instance();
		const dir_contents = ['file1.txt', 'file2.txt', 'subdir'];

		vi.mocked(fs.readdir).mockResolvedValueOnce(dir_contents as any);

		// Make sure to explicitly pass null as the second argument here
		const contents = await safe_fs.readdir('/allowed/path/dir', null);
		expect(contents).toEqual(dir_contents);
		expect(fs.readdir).toHaveBeenCalledWith('/allowed/path/dir', null);
	});

	test('readdir - should throw for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.readdir('/not/allowed/dir')).rejects.toThrow('Path is not allowed');
		expect(fs.readdir).not.toHaveBeenCalled();
	});

	test('rm - should remove files or directories in allowed paths', async () => {
		const safe_fs = create_test_instance();

		vi.mocked(fs.rm).mockResolvedValueOnce();

		await safe_fs.rm('/allowed/path/to-remove', {recursive: true});
		expect(fs.rm).toHaveBeenCalledWith('/allowed/path/to-remove', {recursive: true});
	});

	test('rm - should throw for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.rm('/not/allowed/path')).rejects.toThrow('Path is not allowed');
		expect(fs.rm).not.toHaveBeenCalled();
	});
});

describe('Safe_Fs - Stat Operations and Checks', () => {
	test('stat - should get stats for paths in allowed directories', async () => {
		const safe_fs = create_test_instance();
		const mock_stats = {
			isFile: () => true,
			isDirectory: () => false,
		} as fs_sync.Stats;

		vi.mocked(fs.stat).mockResolvedValueOnce(mock_stats);

		const stats = await safe_fs.stat('/allowed/path/file.txt');
		expect(stats).toBe(mock_stats);
		expect(fs.stat).toHaveBeenCalledWith('/allowed/path/file.txt', {bigint: false});
	});

	test('stat - should throw for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.stat('/not/allowed/file.txt')).rejects.toThrow('Path is not allowed');
		expect(fs.stat).not.toHaveBeenCalled();
	});

	test('lstat - should get lstat for paths in allowed directories', async () => {
		const safe_fs = create_test_instance();
		const mock_stats = {
			isFile: () => true,
			isDirectory: () => false,
			isSymbolicLink: () => false,
		} as fs_sync.Stats;

		vi.mocked(fs.lstat).mockResolvedValueOnce(mock_stats);

		const stats = await safe_fs.lstat('/allowed/path/file.txt');

		// Test the methods rather than the object itself
		expect(stats.isFile()).toBe(mock_stats.isFile());
		expect(stats.isDirectory()).toBe(mock_stats.isDirectory());
		expect(stats.isSymbolicLink()).toBe(mock_stats.isSymbolicLink());
		expect(fs.lstat).toHaveBeenCalledWith('/allowed/path/file.txt', {bigint: false});
	});

	test('lstat - should throw for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.lstat('/not/allowed/file.txt')).rejects.toThrow('Path is not allowed');
		expect(fs.lstat).not.toHaveBeenCalled();
	});

	test('exists - should check existence for paths in allowed directories', async () => {
		const safe_fs = create_test_instance();

		// File exists
		vi.mocked(fs.access).mockResolvedValueOnce();
		let exists = await safe_fs.exists('/allowed/path/exists.txt');
		expect(exists).toBe(true);

		// File doesn't exist
		vi.mocked(fs.access).mockRejectedValueOnce(new Error('ENOENT'));
		exists = await safe_fs.exists('/allowed/path/not-exists.txt');
		expect(exists).toBe(false);
	});

	test('exists - should return false for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		const exists = await safe_fs.exists('/not/allowed/file.txt');
		expect(exists).toBe(false);
		expect(fs.access).not.toHaveBeenCalled();
	});

	test('is_directory - should check if path is a directory in allowed paths', async () => {
		const safe_fs = create_test_instance();

		// Path is a directory - need to mock lstat specifically for this call
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isDirectory: () => true,
				isSymbolicLink: () => false,
				isFile: () => false,
			} as any),
		);

		let is_dir = await safe_fs.is_directory('/allowed/path/dir');
		expect(is_dir).toBe(true);

		// Path is not a directory
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isDirectory: () => false,
				isSymbolicLink: () => false,
				isFile: () => true,
			} as any),
		);

		is_dir = await safe_fs.is_directory('/allowed/path/file.txt');
		expect(is_dir).toBe(false);
	});

	test('is_directory - should return false for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		const is_dir = await safe_fs.is_directory('/not/allowed/dir');
		expect(is_dir).toBe(false);
	});

	test('is_file - should check if path is a file in allowed paths', async () => {
		const safe_fs = create_test_instance();

		// Path is a file
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isFile: () => true,
				isSymbolicLink: () => false,
				isDirectory: () => false,
			} as any),
		);

		let is_file = await safe_fs.is_file('/allowed/path/file.txt');
		expect(is_file).toBe(true);

		// Path is not a file
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isFile: () => false,
				isSymbolicLink: () => false,
				isDirectory: () => true,
			} as any),
		);

		is_file = await safe_fs.is_file('/allowed/path/dir');
		expect(is_file).toBe(false);
	});

	test('is_file - should return false for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		const is_file = await safe_fs.is_file('/not/allowed/file.txt');
		expect(is_file).toBe(false);
	});
});

describe('Safe_Fs - Security Features', () => {
	test('symlink detection - should reject operations on symlinks', async () => {
		const safe_fs = create_test_instance();

		// Mock path as symlink
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => true,
				isFile: () => false,
				isDirectory: () => false,
			} as any),
		);

		await expect(safe_fs.read_file('/allowed/path/symlink')).rejects.toThrow(
			'Path is a symlink which is not allowed',
		);
		expect(fs.readFile).not.toHaveBeenCalled();
	});

	test('symlink detection - should check parent directories for symlinks', async () => {
		const safe_fs = create_test_instance();

		// Setup - first validate path allowed, then detect symlink in parent
		vi.mocked(fs_sync.existsSync).mockImplementation((path) => {
			if (typeof path === 'string') {
				return path === '/allowed/path/symlink-dir' || path === '/allowed/path';
			}
			return false;
		});

		// Mock a sequence of lstat calls:
		// First for target path, not a symlink
		vi.mocked(fs.lstat)
			.mockImplementationOnce(() =>
				Promise.resolve({
					isSymbolicLink: () => false,
					isFile: () => true,
				} as any),
			)
			.mockImplementationOnce(() =>
				Promise.resolve({
					isSymbolicLink: () => true,
					isDirectory: () => true,
				} as any),
			);

		await expect(safe_fs.read_file('/allowed/path/symlink-dir/file.txt')).rejects.toThrow(
			/symlink which is not allowed/,
		);

		expect(fs.readFile).not.toHaveBeenCalled();
	});

	test('is_symlink - should detect symlinks in allowed paths', async () => {
		const safe_fs = create_test_instance();

		// Path is a symlink
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => true,
				isFile: () => false,
				isDirectory: () => false,
			} as any),
		);

		let is_sym = await safe_fs.is_symlink('/allowed/path/symlink');
		expect(is_sym).toBe(true);

		// Path is not a symlink
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => false,
				isFile: () => true,
				isDirectory: () => false,
			} as any),
		);

		is_sym = await safe_fs.is_symlink('/allowed/path/regular-file');
		expect(is_sym).toBe(false);
	});

	test('is_symlink - should return false for paths outside allowed directories', async () => {
		const safe_fs = create_test_instance();

		const is_sym = await safe_fs.is_symlink('/not/allowed/symlink');
		expect(is_sym).toBe(false);
	});

	test('path traversal prevention - should reject path traversal attempts', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.read_file('/allowed/path/../../../etc/passwd')).rejects.toThrow(
			'Path is not allowed',
		);
		await expect(safe_fs.read_file('/allowed/path/../not-allowed/file')).rejects.toThrow(
			'Path is not allowed',
		);
		expect(fs.readFile).not.toHaveBeenCalled();
	});

	test('relative path rejection - should reject relative paths', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.read_file('relative/path/file.txt')).rejects.toThrow(
			'Path is not allowed',
		);
		await expect(safe_fs.read_file('./file.txt')).rejects.toThrow('Path is not allowed');
		await expect(safe_fs.read_file('../file.txt')).rejects.toThrow('Path is not allowed');
		expect(fs.readFile).not.toHaveBeenCalled();
	});
});

describe('Safe_Fs - Edge Cases and Error Handling', () => {
	test('empty string paths - should be rejected', async () => {
		const safe_fs = create_test_instance();

		await expect(safe_fs.read_file('')).rejects.toThrow('Path is not allowed');
		expect(fs.readFile).not.toHaveBeenCalled();
	});

	test('filesystem errors - should be propagated', async () => {
		const safe_fs = create_test_instance();

		const file_error = new Error('File not found');
		vi.mocked(fs.readFile).mockRejectedValueOnce(file_error);

		await expect(safe_fs.read_file('/allowed/path/missing.txt')).rejects.toThrow('File not found');
		expect(fs.readFile).toHaveBeenCalledWith('/allowed/path/missing.txt', undefined);
	});

	test('path with Unicode characters - should work correctly', async () => {
		const safe_fs = create_test_instance();

		vi.mocked(fs.readFile).mockResolvedValueOnce('content' as any);

		await safe_fs.read_file('/allowed/path/файл.txt');
		expect(fs.readFile).toHaveBeenCalledWith('/allowed/path/файл.txt', undefined);
	});

	test('path with spaces and special characters - should work correctly', async () => {
		const safe_fs = create_test_instance();

		vi.mocked(fs.readFile).mockResolvedValueOnce('content' as any);

		await safe_fs.read_file('/allowed/path/file with spaces!@#.txt');
		expect(fs.readFile).toHaveBeenCalledWith('/allowed/path/file with spaces!@#.txt', undefined);
	});

	test('parent directory exists but not the file - should still work', async () => {
		const safe_fs = create_test_instance();

		// Parent exists but file doesn't
		vi.mocked(fs_sync.existsSync).mockImplementation((path) => {
			if (typeof path === 'string') {
				return path === '/allowed/path';
			}
			return false;
		});

		const lstatMock = vi.mocked(fs.lstat);
		lstatMock.mockImplementationOnce(() =>
			Promise.reject(new Error('ENOENT: no such file or directory')),
		);

		// When checking parent directory:
		lstatMock.mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => false,
				isDirectory: () => true,
			} as any),
		);

		// For readFile to throw its own error
		vi.mocked(fs.readFile).mockRejectedValueOnce(new Error('ENOENT: no such file or directory'));

		// Should pass path validation but fail on actual fs operation
		await expect(safe_fs.read_file('/allowed/path/new-file.txt')).rejects.toThrow(/ENOENT:.+/);
		expect(fs.readFile).toHaveBeenCalled();
	});
});

describe('Safe_Fs - Special Path Handling', () => {
	test('root directory - special handling', () => {
		// With root directory allowed
		const root_safe_fs = new Safe_Fs(['/']);

		expect(root_safe_fs.is_path_allowed('/')).toBe(true);
		expect(root_safe_fs.is_path_allowed('/any/path/anywhere.txt')).toBe(true);
		expect(root_safe_fs.is_path_allowed('/etc/passwd')).toBe(true);
	});

	test('trailing slash handling - paths should match with or without trailing slash', () => {
		const dirs_with_slashes = ['/dir/with/slash/', '/another/dir/with/slash/'];
		const dirs_without_slashes = ['/dir/without/slash', '/another/dir/without/slash'];

		const safe_fs1 = new Safe_Fs(dirs_with_slashes);
		const safe_fs2 = new Safe_Fs(dirs_without_slashes);

		// Test with dirs that have trailing slashes
		expect(safe_fs1.is_path_allowed('/dir/with/slash')).toBe(true); // Without slash still matches
		expect(safe_fs1.is_path_allowed('/dir/with/slash/')).toBe(true); // With slash matches
		expect(safe_fs1.is_path_allowed('/dir/with/slash/file.txt')).toBe(true); // Child file matches

		// Test with dirs that don't have trailing slashes
		expect(safe_fs2.is_path_allowed('/dir/without/slash')).toBe(true); // Without slash matches
		expect(safe_fs2.is_path_allowed('/dir/without/slash/')).toBe(true); // With slash still matches
		expect(safe_fs2.is_path_allowed('/dir/without/slash/file.txt')).toBe(true); // Child file matches
	});

	test('similar path prefixes - should not match similar but different paths', () => {
		const safe_fs = new Safe_Fs(['/allowed/path']);

		expect(safe_fs.is_path_allowed('/allowed/path')).toBe(true);
		expect(safe_fs.is_path_allowed('/allowed/path-extra')).toBe(false); // Similar but different
		expect(safe_fs.is_path_allowed('/allowed/pathological')).toBe(false); // Similar but different
		expect(safe_fs.is_path_allowed('/allowed/pa')).toBe(false); // Partial path
	});
});

describe('Safe_Fs - Error Classes', () => {
	test('custom error classes - should have correct properties', () => {
		const path_error = new Path_Not_Allowed_Error('/some/path');
		expect(path_error.message).toBe('Path is not allowed: /some/path');
		expect(path_error.name).toBe('Path_Not_Allowed_Error');

		const symlink_error = new Symlink_Not_Allowed_Error('/some/link');
		expect(symlink_error.message).toBe('Path is a symlink which is not allowed: /some/link');
		expect(symlink_error.name).toBe('Symlink_Not_Allowed_Error');
	});
});
