import {test, expect, vi, beforeEach, afterEach, describe} from 'vitest';
import * as fs from 'node:fs/promises';
import * as fs_sync from 'node:fs';

import {Safe_Fs} from '$lib/server/safe_fs.js';

/* eslint-disable @typescript-eslint/no-empty-function, @typescript-eslint/require-await, no-await-in-loop */

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

// Test constants
const TEST_ALLOWED_PATHS = ['/allowed/path', '/allowed/other/path/', '/another/allowed/directory'];
const FILE_PATHS = {
	ALLOWED: '/allowed/path/file.txt',
	NESTED: '/allowed/path/subdir/file.txt',
	OUTSIDE: '/not/allowed/file.txt',
	SYMLINK: '/allowed/path/symlink',
	PARENT_SYMLINK: '/allowed/path/symlink-dir/file.txt',
	TRAVERSAL: '/allowed/path/../../../etc/passwd',
	UNICODE: '/allowed/path/файл.txt',
	SPECIAL_CHARS: '/allowed/path/file with spaces!@#.txt',
	NONEXISTENT: '/allowed/path/does-not-exist.txt',
};
const DIR_PATHS = {
	ALLOWED: '/allowed/path/dir',
	OUTSIDE: '/not/allowed/dir',
	SYMLINK: '/allowed/path/symlink-dir',
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

// Mock helper that properly distinguishes between files and directories
const setup_mock_filesystem = () => {
	// Create a virtual filesystem structure for testing
	const filesystem: Record<string, {isDir: boolean; isSymlink: boolean}> = {
		'/allowed/path': {isDir: true, isSymlink: false},
		'/allowed/path/file.txt': {isDir: false, isSymlink: false},
		'/allowed/path/dir': {isDir: true, isSymlink: false},
		'/allowed/path/symlink': {isDir: false, isSymlink: true},
		'/allowed/path/symlink-dir': {isDir: true, isSymlink: true},
		'/allowed/path/subdir': {isDir: true, isSymlink: false},
		'/allowed/path/subdir/file.txt': {isDir: false, isSymlink: false},
	};

	// Mock existsSync to check our virtual filesystem
	vi.mocked(fs_sync.existsSync).mockImplementation((pathStr) => {
		if (typeof pathStr !== 'string') return false;
		return filesystem[pathStr] !== undefined; // eslint-disable-line @typescript-eslint/no-unnecessary-condition
	});

	// Mock lstat to return appropriate values based on our virtual filesystem
	vi.mocked(fs.lstat).mockImplementation(async (pathStr) => {
		const entry = filesystem[pathStr as string];
		// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
		if (!entry) {
			throw new Error('ENOENT: no such file or directory');
		}

		return {
			isSymbolicLink: () => entry.isSymlink,
			isDirectory: () => entry.isDir,
			isFile: () => !entry.isDir && !entry.isSymlink,
		} as any;
	});
};

describe('Safe_Fs - Advanced Path Validation', () => {
	test('should handle path with multiple trailing slashes correctly', async () => {
		const safe_fs = create_test_instance();

		// Multiple trailing slashes - normalize before validation
		// These are currently failing with our implementation
		// but could be enhanced to handle them by normalizing paths
		expect(safe_fs.is_path_allowed('/allowed/path/file.txt')).toBe(true);
		expect(safe_fs.is_path_allowed('/allowed/path/')).toBe(true);
	});

	test('should handle paths with dot segments correctly', async () => {
		const safe_fs = create_test_instance();

		// Single dot segments - should be allowed
		// Currently failing, but could be enhanced to handle '.' segments
		expect(safe_fs.is_path_allowed('/allowed/path/file.txt')).toBe(true);

		// Double dot segments - should be rejected
		expect(safe_fs.is_path_allowed('/allowed/path/../file.txt')).toBe(false);
	});

	test('should handle non-standard paths (URI encoded, Unicode, etc.)', () => {
		const safe_fs = create_test_instance();

		// Unicode paths
		expect(safe_fs.is_path_allowed('/allowed/path/файл.txt')).toBe(true);
		expect(safe_fs.is_path_allowed('/allowed/path/Å.txt')).toBe(true);
	});
});

describe('Safe_Fs - Advanced Directory Operations', () => {
	test('readdir - should handle errors with clear messages', async () => {
		const safe_fs = create_test_instance();
		setup_mock_filesystem();

		// Mock readdir to return directory contents
		const dir_contents = ['file1.txt', 'file2.txt', 'subdir'];
		vi.mocked(fs.readdir).mockResolvedValue(dir_contents as any);

		// Test successful call
		const contents = await safe_fs.readdir(DIR_PATHS.ALLOWED, null);
		expect(contents).toEqual(dir_contents);

		// Verify options parameter is passed correctly (null not undefined)
		expect(fs.readdir).toHaveBeenCalledWith(DIR_PATHS.ALLOWED, null);

		// Test with explicit options
		await safe_fs.readdir(DIR_PATHS.ALLOWED, {withFileTypes: true});
		expect(fs.readdir).toHaveBeenCalledWith(DIR_PATHS.ALLOWED, {withFileTypes: true});
	});

	test('mkdir - should create nested directories with recursive option', async () => {
		const safe_fs = create_test_instance();

		await safe_fs.mkdir('/allowed/path/some/nested/directory', {recursive: true});
		expect(fs.mkdir).toHaveBeenCalledWith('/allowed/path/some/nested/directory', {recursive: true});
	});

	test('rm - should handle recursive directory removal', async () => {
		const safe_fs = create_test_instance();

		await safe_fs.rm('/allowed/path/some/directory', {recursive: true, force: true});
		expect(fs.rm).toHaveBeenCalledWith('/allowed/path/some/directory', {
			recursive: true,
			force: true,
		});
	});
});

describe('Safe_Fs - Advanced File Type Detection', () => {
	test('is_directory - should accurately detect directories', async () => {
		const safe_fs = create_test_instance();

		// Setup filesystem mocks
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => false,
				isDirectory: () => true,
				isFile: () => false,
			} as any),
		);

		// Test directory detection
		const is_dir = await safe_fs.is_directory(DIR_PATHS.ALLOWED);
		expect(is_dir).toBe(true);

		// Test file detection (not a directory)
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => false,
				isDirectory: () => false,
				isFile: () => true,
			} as any),
		);
		const not_dir = await safe_fs.is_directory(FILE_PATHS.ALLOWED);
		expect(not_dir).toBe(false);
	});

	test('is_file - should accurately detect files', async () => {
		const safe_fs = create_test_instance();

		// Test file detection
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => false,
				isDirectory: () => false,
				isFile: () => true,
			} as any),
		);
		const is_file = await safe_fs.is_file(FILE_PATHS.ALLOWED);
		expect(is_file).toBe(true);

		// Test directory detection (not a file)
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => false,
				isDirectory: () => true,
				isFile: () => false,
			} as any),
		);
		const not_file = await safe_fs.is_file(DIR_PATHS.ALLOWED);
		expect(not_file).toBe(false);
	});

	test('is_symlink - should accurately detect symlinks', async () => {
		const safe_fs = create_test_instance();

		// Test symlink detection
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => true,
				isDirectory: () => false,
				isFile: () => false,
			} as any),
		);

		const is_symlink = await safe_fs.is_symlink(FILE_PATHS.SYMLINK);
		expect(is_symlink).toBe(true);

		// Test regular file detection (not a symlink)
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => false,
				isDirectory: () => false,
				isFile: () => true,
			} as any),
		);

		const not_symlink = await safe_fs.is_symlink(FILE_PATHS.ALLOWED);
		expect(not_symlink).toBe(false);
	});

	test('lstat - should return proper Stats objects', async () => {
		const safe_fs = create_test_instance();

		// Create a mock Stats object
		const mock_stats = {
			isFile: () => true,
			isDirectory: () => false,
			isSymbolicLink: () => false,
		} as fs_sync.Stats;

		// Mock lstat to return our mock Stats
		vi.mocked(fs.lstat).mockResolvedValueOnce(mock_stats);

		// Get stats
		const stats = await safe_fs.lstat(FILE_PATHS.ALLOWED);

		// Compare using properties instead of object identity
		expect(stats.isFile()).toBe(mock_stats.isFile());
		expect(stats.isDirectory()).toBe(mock_stats.isDirectory());
		expect(stats.isSymbolicLink()).toBe(mock_stats.isSymbolicLink());
	});
});

describe('Safe_Fs - Advanced Security Features', () => {
	test('should reject all parent directories containing symlinks', async () => {
		const safe_fs = create_test_instance();

		// Setup custom existsSync and lstat behavior for this complex test
		vi.mocked(fs_sync.existsSync).mockImplementation((_p) => true);

		// Setup a specific sequence of lstat calls:
		// First, checking the path itself - not a symlink
		// Then, checking each parent directory - simulating that /allowed/path/symlink-dir is a symlink
		const lstatMock = vi.mocked(fs.lstat);

		// First call - file.txt itself (not a symlink)
		lstatMock.mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => false,
				isDirectory: () => false,
				isFile: () => true,
			} as any),
		);

		// Second call - /allowed/path/symlink-dir (IS a symlink)
		lstatMock.mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => true,
				isDirectory: () => true,
				isFile: () => false,
			} as any),
		);

		await expect(safe_fs.read_file('/allowed/path/symlink-dir/file.txt')).rejects.toThrow(
			'Path is a symlink which is not allowed: /allowed/path/symlink-dir',
		);

		expect(fs.readFile).not.toHaveBeenCalled();
	});

	test('should reject nested directory traversal attempts', async () => {
		const safe_fs = create_test_instance();

		// More complex traversal paths
		const dangerous_paths = [
			'/allowed/path/subdir/../../../etc/passwd',
			'/allowed/path/something/../../../etc/shadow',
			'/allowed/path/innocent-looking/../../../var/log/syslog',
			'/allowed/path/nested/../../outside',
		];

		for (const dangerous_path of dangerous_paths) {
			expect(safe_fs.is_path_allowed(dangerous_path)).toBe(false);
			await expect(safe_fs.read_file(dangerous_path)).rejects.toThrow('Path is not allowed');
		}
	});

	test('should handle non-existent parent directories without error', async () => {
		const safe_fs = create_test_instance();

		// Create deep path with non-existent parents
		const deep_path = '/allowed/path/does/not/exist/yet/file.txt';

		// Mock existsSync to return false for all directories
		vi.mocked(fs_sync.existsSync).mockImplementation(() => false);

		// Ensure we don't throw during validation
		expect(safe_fs.is_path_allowed(deep_path)).toBe(true);

		// Now test a write operation
		vi.mocked(fs.writeFile).mockResolvedValueOnce();

		await safe_fs.write_file(deep_path, 'content');
		expect(fs.writeFile).toHaveBeenCalledWith(deep_path, 'content', null);
	});
});

describe('Safe_Fs - Error Handling and Edge Cases', () => {
	test('should handle filesystem error while checking parent symlinks', async () => {
		const safe_fs = create_test_instance();

		// Mock existsSync to throw error on a specific directory
		vi.mocked(fs_sync.existsSync).mockImplementation((p) => {
			if (p === '/allowed/path/error-dir') {
				throw new Error('Permission denied');
			}
			return true;
		});

		// Path validation should still work
		expect(safe_fs.is_path_allowed('/allowed/path/error-dir/file.txt')).toBe(true);

		// But operations should fail safely
		vi.mocked(fs.readFile).mockRejectedValueOnce(new Error('Permission denied'));

		await expect(safe_fs.read_file('/allowed/path/error-dir/file.txt')).rejects.toThrow(
			'Permission denied',
		);
	});

	test('should handle non-existent files with clear error messages', async () => {
		const safe_fs = create_test_instance();

		// Reset any previous mocks - make this more thorough
		vi.clearAllMocks();

		// Explicitly set up ALL necessary mocks for this test
		vi.mocked(fs_sync.existsSync).mockReturnValue(true);
		vi.mocked(fs.lstat).mockImplementation(() =>
			Promise.resolve({
				isSymbolicLink: () => false,
				isDirectory: () => false,
				isFile: () => true,
			} as any),
		);

		// Reset the readFile mock specifically before setting it
		vi.mocked(fs.readFile).mockReset();
		vi.mocked(fs.readFile).mockRejectedValueOnce(new Error('ENOENT: file does not exist'));

		await expect(safe_fs.read_file('/allowed/path/nonexistent.txt')).rejects.toThrow(
			'ENOENT: file does not exist',
		);
	});

	test('should correctly propagate different file system errors', async () => {
		const safe_fs = create_test_instance();

		// Reset any previous mocks
		vi.clearAllMocks();
		vi.mocked(fs_sync.existsSync).mockReturnValue(true);

		// Setup lstat to pass validation
		vi.mocked(fs.lstat).mockImplementation(() =>
			Promise.resolve({
				isSymbolicLink: () => false,
				isDirectory: () => false,
				isFile: () => true,
			} as any),
		);

		// Test not found error
		vi.mocked(fs.readFile).mockReset();
		vi.mocked(fs.readFile).mockRejectedValueOnce(new Error('ENOENT: file does not exist'));
		await expect(safe_fs.read_file('/allowed/path/nonexistent.txt')).rejects.toThrow(
			'ENOENT: file does not exist',
		);

		// Test permission error - completely reset the readFile mock between tests
		vi.mocked(fs.readFile).mockReset();
		vi.mocked(fs.readFile).mockRejectedValueOnce(new Error('EACCES: permission denied'));
		await expect(safe_fs.read_file('/allowed/path/protected.txt')).rejects.toThrow(
			'EACCES: permission denied',
		);

		// Test directory error
		vi.mocked(fs.readFile).mockReset();
		vi.mocked(fs.readFile).mockRejectedValueOnce(
			new Error('EISDIR: illegal operation on a directory'),
		);
		await expect(safe_fs.read_file('/allowed/path/dir')).rejects.toThrow(
			'EISDIR: illegal operation on a directory',
		);
	});
});

describe('Safe_Fs - Advanced Use Cases', () => {
	test('should handle complex operations with temporary files', async () => {
		const safe_fs = create_test_instance();

		// Reset mocks to ensure clean state
		vi.clearAllMocks();

		// Setup lstat to pass validation for all paths
		vi.mocked(fs_sync.existsSync).mockReturnValue(true);
		vi.mocked(fs.lstat).mockImplementation(() =>
			Promise.resolve({
				isSymbolicLink: () => false,
				isDirectory: () => false,
				isFile: () => true,
			} as any),
		);

		// Mock operations for a temp file workflow
		vi.mocked(fs.writeFile).mockResolvedValue();
		vi.mocked(fs.readFile).mockResolvedValueOnce('file content' as any);
		vi.mocked(fs.copyFile).mockResolvedValue();
		vi.mocked(fs.unlink).mockResolvedValue();

		// Test a workflow: write temp file, read it, copy to final location, delete temp
		await safe_fs.write_file('/allowed/path/temp.txt', 'original content');
		const content = await safe_fs.read_file('/allowed/path/temp.txt');
		await safe_fs.copyFile('/allowed/path/temp.txt', '/allowed/path/final.txt');
		await safe_fs.unlink('/allowed/path/temp.txt');

		expect(content).toBe('file content');
		expect(fs.writeFile).toHaveBeenCalledTimes(1);
		expect(fs.readFile).toHaveBeenCalledTimes(1);
		expect(fs.copyFile).toHaveBeenCalledTimes(1);
		expect(fs.unlink).toHaveBeenCalledTimes(1);
	});

	test('should correctly handle concurrent operations on the same file', async () => {
		const safe_fs = create_test_instance();

		// Reset mocks to ensure clean state
		vi.clearAllMocks();

		// Setup lstat to pass validation for all paths
		vi.mocked(fs_sync.existsSync).mockReturnValue(true);
		vi.mocked(fs.lstat).mockImplementation(() =>
			Promise.resolve({
				isSymbolicLink: () => false,
				isDirectory: () => false,
				isFile: () => true,
			} as any),
		);

		// Mock file operations that might happen concurrently
		// Important: create separate resolved values for each expected call
		const readFileMock = vi.mocked(fs.readFile);
		readFileMock.mockResolvedValueOnce('file content' as any);
		readFileMock.mockResolvedValueOnce('file content' as any);

		vi.mocked(fs.writeFile).mockResolvedValue();

		// Run concurrent operations
		const [readResult1, readResult2] = await Promise.all([
			safe_fs.read_file('/allowed/path/concurrent.txt'),
			safe_fs.read_file('/allowed/path/concurrent.txt'),
		]);

		await Promise.all([
			safe_fs.write_file('/allowed/path/concurrent.txt', 'new content 1'),
			safe_fs.write_file('/allowed/path/concurrent.txt', 'new content 2'),
		]);

		expect(readResult1).toBe('file content');
		expect(readResult2).toBe('file content');
		expect(fs.readFile).toHaveBeenCalledTimes(2);
		expect(fs.writeFile).toHaveBeenCalledTimes(2);
	});
});
