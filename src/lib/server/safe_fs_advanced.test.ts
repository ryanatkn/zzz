import {test, expect, vi, beforeEach, afterEach, describe} from 'vitest';
import * as fs from 'node:fs/promises';
import * as fs_sync from 'node:fs';

import {Safe_Fs, Symlink_Not_Allowed_Error} from '$lib/server/safe_fs.js';

/* eslint-disable @typescript-eslint/require-await, @typescript-eslint/no-empty-function, no-await-in-loop */

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
	UNICODE: '/allowed/path/файл.txt',
	SPECIAL_CHARS: '/allowed/path/file with spaces!@#.txt',
	NONEXISTENT: '/allowed/path/does-not-exist.txt',
	SYMLINK: '/allowed/path/symlink',
	PARENT_SYMLINK: '/allowed/path/symlink-dir/file.txt',
};
const DIR_PATHS = {
	ALLOWED: '/allowed/path/dir',
	OUTSIDE: '/not/allowed/dir',
	NEW_DIR: '/allowed/path/new-dir',
	SYMLINK: '/allowed/path/symlink-dir',
	NESTED: '/allowed/path/nested/directory/structure',
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

// Helper to set up mock filesystem structure
const setup_mock_filesystem = () => {
	const filesystem = {
		'/allowed/path': {isDir: true, isSymlink: false},
		'/allowed/path/file.txt': {isDir: false, isSymlink: false},
		'/allowed/path/dir': {isDir: true, isSymlink: false},
		'/allowed/path/symlink': {isDir: false, isSymlink: true},
		'/allowed/path/symlink-dir': {isDir: true, isSymlink: true},
		'/allowed/path/subdir': {isDir: true, isSymlink: false},
		'/allowed/path/subdir/file.txt': {isDir: false, isSymlink: false},
		'/allowed/path/файл.txt': {isDir: false, isSymlink: false},
		'/allowed/path/file with spaces!@#.txt': {isDir: false, isSymlink: false},
	};

	vi.mocked(fs_sync.existsSync).mockImplementation((pathStr) => {
		if (typeof pathStr !== 'string') return false;
		return (filesystem as any)[pathStr] !== undefined;
	});

	vi.mocked(fs.lstat).mockImplementation(async (pathStr) => {
		const entry = (filesystem as any)[pathStr as string];
		if (!entry) {
			throw new Error('ENOENT: no such file or directory');
		}

		return {
			isSymbolicLink: () => entry.isSymlink,
			isDirectory: () => entry.isDir,
			isFile: () => !entry.isDir && !entry.isSymlink,
		} as any;
	});

	return filesystem;
};

describe('Safe_Fs - Advanced Path Validation', () => {
	test('should handle paths with special characters correctly', () => {
		const safe_fs = create_test_instance();

		const special_paths = [
			FILE_PATHS.UNICODE,
			FILE_PATHS.SPECIAL_CHARS,
			'/allowed/path/Å.txt',
			'/allowed/path/🔥.txt',
			'/allowed/path/path with multiple spaces/file.txt',
			'/allowed/path/path-with-dashes/file.txt',
			'/allowed/path/path_with_underscores/file.txt',
		];

		// All should be allowed
		for (const path of special_paths) {
			expect(safe_fs.is_path_allowed(path)).toBe(true);
		}
	});

	test('should handle multiple trailing slashes and normalize paths', () => {
		const safe_fs = create_test_instance();

		// These paths should all be allowed and normalized internally
		const paths_with_multiple_slashes = [
			'/allowed/path//',
			'/allowed/path//file.txt',
			'/allowed/path////',
			'/allowed/path////file.txt',
		];

		for (const path of paths_with_multiple_slashes) {
			expect(safe_fs.is_path_allowed(path)).toBe(true);
		}
	});

	test('should validate complex path combinations', async () => {
		const safe_fs = create_test_instance();

		const valid_paths = [
			'/allowed/path',
			'/allowed/path/',
			'/allowed/other/path',
			'/allowed/other/path/',
			'/allowed/path/a/b/c/d/deep/nested/path',
			'/allowed/path/././file.txt', // This will be normalized
		];

		const invalid_paths = [
			'/allowed/pathextra',
			'/allowedpath/file.txt',
			'/allowed/./path/../../../etc/passwd',
			'/allowed/path/../../file.txt',
		];

		// Test valid paths
		for (const path of valid_paths) {
			expect(safe_fs.is_path_allowed(path)).toBe(true);
			expect(await safe_fs.is_path_safe(path)).toBe(true);
		}

		// Test invalid paths
		for (const path of invalid_paths) {
			expect(safe_fs.is_path_allowed(path)).toBe(false);
			expect(await safe_fs.is_path_safe(path)).toBe(false);
		}
	});
});

describe('Safe_Fs - Advanced Directory Operations', () => {
	test('readdir - should handle different option combinations', async () => {
		const safe_fs = create_test_instance();
		setup_mock_filesystem();

		const readdir_options = [
			null,
			'utf8',
			{},
			{withFileTypes: false},
			{withFileTypes: true},
			{recursive: true},
			{encoding: 'utf8'},
			{withFileTypes: true, recursive: true},
		];

		// Setup mock responses for regular files and Dirent objects
		const files = ['file1.txt', 'file2.txt', 'subdir'];
		const dirents = files.map((name) => ({
			name,
			isFile: () => !name.includes('dir'),
			isDirectory: () => name.includes('dir'),
			isSymbolicLink: () => false,
		}));

		for (const option of readdir_options) {
			vi.mocked(fs.readdir).mockReset();

			if (
				option &&
				typeof option === 'object' &&
				'withFileTypes' in option &&
				option.withFileTypes
			) {
				vi.mocked(fs.readdir).mockResolvedValueOnce(dirents as any);
			} else {
				vi.mocked(fs.readdir).mockResolvedValueOnce(files as any);
			}

			await safe_fs.readdir(DIR_PATHS.ALLOWED, option as any);
			expect(fs.readdir).toHaveBeenCalledWith(DIR_PATHS.ALLOWED, option);
		}
	});

	test('mkdir - should create nested directory structures', async () => {
		const safe_fs = create_test_instance();

		// Test creating a deeply nested directory
		await safe_fs.mkdir(DIR_PATHS.NESTED, {recursive: true});
		expect(fs.mkdir).toHaveBeenCalledWith(DIR_PATHS.NESTED, {recursive: true});

		// Without recursive flag, it should still try to create the directory
		await safe_fs.mkdir(DIR_PATHS.NEW_DIR);
		expect(fs.mkdir).toHaveBeenCalledWith(DIR_PATHS.NEW_DIR, undefined);

		// Should properly bubble up errors from fs.mkdir
		const error = new Error('EEXIST: directory already exists');
		vi.mocked(fs.mkdir).mockRejectedValueOnce(error);

		await expect(safe_fs.mkdir(DIR_PATHS.ALLOWED)).rejects.toThrow(error);
	});

	test('rm - should handle various removal options', async () => {
		const safe_fs = create_test_instance();

		const rm_options_combinations = [
			undefined,
			{},
			{recursive: true},
			{force: true},
			{recursive: true, force: true},
		];

		for (const options of rm_options_combinations) {
			vi.mocked(fs.rm).mockReset();
			vi.mocked(fs.rm).mockResolvedValueOnce();

			await safe_fs.rm(DIR_PATHS.ALLOWED, options);
			expect(fs.rm).toHaveBeenCalledWith(DIR_PATHS.ALLOWED, options);
		}
	});
});

describe('Safe_Fs - Advanced Security Features', () => {
	test('should reject all symlinks in path hierarchy', async () => {
		const safe_fs = create_test_instance();

		// Setup a virtual file system where different components are symlinks
		const symlink_test_cases = [
			{
				description: 'Target file is a symlink',
				path: FILE_PATHS.SYMLINK,
				symlink_at: FILE_PATHS.SYMLINK,
			},
			{
				description: 'Parent directory is a symlink',
				path: FILE_PATHS.PARENT_SYMLINK,
				symlink_at: '/allowed/path/symlink-dir',
			},
			{
				description: 'Grandparent directory is a symlink',
				path: '/allowed/path/dir/subdir/file.txt',
				symlink_at: '/allowed/path/dir',
			},
		];

		for (const {path, symlink_at} of symlink_test_cases) {
			// Reset mocks for each test case
			vi.mocked(fs.lstat).mockReset();
			vi.mocked(fs_sync.existsSync).mockReturnValue(true);

			// Setup a custom lstat implementation for this test case
			vi.mocked(fs.lstat).mockImplementation(async (p) => {
				if (p === symlink_at) {
					return {
						isSymbolicLink: () => true,
						isDirectory: () => p.endsWith('dir'),
						isFile: () => !p.endsWith('dir'),
					} as any;
				}
				return {
					isSymbolicLink: () => false,
					isDirectory: () => String(p).includes('dir'),
					isFile: () => !String(p).includes('dir'),
				} as any;
			});

			// Each case should be rejected with a Symlink_Not_Allowed_Error
			await expect(safe_fs.read_file(path)).rejects.toThrow(Symlink_Not_Allowed_Error);
			expect(fs.readFile).not.toHaveBeenCalled();
		}
	});

	test('should detect sophisticated path traversal attempts', async () => {
		const safe_fs = create_test_instance();

		const tricky_traversal_paths = [
			'/allowed/path/subdir/../../../etc/passwd', // Multiple traversals
			'/allowed/path/./subdir/../../outside', // Mixed ./ and ../
			'/allowed/path/subdir/.././../outside', // Convoluted traversal
			'/allowed/path/foo/../bar/../../../etc/passwd', // Alternating good and bad segments
			'/allowed/path/normal/../normal/../../../out', // Looks somewhat legitimate
		];

		for (const path of tricky_traversal_paths) {
			expect(safe_fs.is_path_allowed(path)).toBe(false);
			await expect(safe_fs.read_file(path)).rejects.toThrow('Path is not allowed');
		}
	});

	test('exists should use robust path validation including symlink checks', async () => {
		const safe_fs = create_test_instance();

		// Setup symlink detection
		vi.mocked(fs.lstat).mockImplementationOnce(() =>
			Promise.resolve({
				isSymbolicLink: () => true,
				isDirectory: () => false,
				isFile: () => false,
			} as any),
		);

		// Should detect symlink and return false without calling access
		const exists = await safe_fs.exists('/allowed/path/evil-symlink');
		expect(exists).toBe(false);
		expect(fs.access).not.toHaveBeenCalled();
	});
});

describe('Safe_Fs - Error Handling and Edge Cases', () => {
	test('should handle filesystem errors during path validation gracefully', async () => {
		const safe_fs = create_test_instance();

		// Setup lstat to throw an unusual error
		vi.mocked(fs.lstat).mockRejectedValue(new Error('Unknown filesystem error'));

		// The error during symlink check should be caught and rethrown
		await expect(safe_fs.read_file(FILE_PATHS.ALLOWED)).rejects.toThrow('Unknown filesystem error');
		expect(fs.readFile).not.toHaveBeenCalled();
	});

	test('should handle a variety of filesystem errors from underlying operations', async () => {
		const safe_fs = create_test_instance();

		// Reset lstat to normal behavior
		vi.mocked(fs.lstat).mockImplementation(() =>
			Promise.resolve({
				isSymbolicLink: () => false,
				isDirectory: () => false,
				isFile: () => true,
			} as any),
		);

		// Test different fs errors
		const fs_errors = [
			{message: 'ENOENT: no such file or directory', code: 'ENOENT'},
			{message: 'EACCES: permission denied', code: 'EACCES'},
			{message: 'EISDIR: illegal operation on a directory', code: 'EISDIR'},
			{message: 'ENOSPC: no space left on device', code: 'ENOSPC'},
			{message: 'EIO: input/output error', code: 'EIO'},
		];

		for (const {message, code} of fs_errors) {
			const error = new Error(message);
			(error as any).code = code;

			// Reset and configure mock for each error type
			vi.mocked(fs.readFile).mockReset();
			vi.mocked(fs.readFile).mockRejectedValueOnce(error);

			// Error should be passed through
			await expect(safe_fs.read_file(FILE_PATHS.ALLOWED)).rejects.toThrow(message);
			expect(fs.readFile).toHaveBeenCalledWith(FILE_PATHS.ALLOWED, 'utf8');
		}
	});

	test('should handle nonexistent parent directories correctly', async () => {
		const safe_fs = create_test_instance();
		const deep_nonexistent_path = '/allowed/path/does/not/exist/yet/file.txt';

		// Setup existsSync to simulate missing directories
		vi.mocked(fs_sync.existsSync).mockImplementation((p) => {
			return String(p) === '/allowed/path'; // Only the base allowed path exists
		});

		// The path itself is allowed since it's under an allowed directory
		expect(safe_fs.is_path_allowed(deep_nonexistent_path)).toBe(true);

		// Write operation should be allowed after path validation
		vi.mocked(fs.writeFile).mockResolvedValueOnce();

		await safe_fs.write_file(deep_nonexistent_path, 'content');
		expect(fs.writeFile).toHaveBeenCalledWith(deep_nonexistent_path, 'content', 'utf8');
	});

	test('should handle extreme edge cases gracefully', async () => {
		const safe_fs = create_test_instance();

		// Test with various edge case paths
		const edge_case_paths = [
			'/allowed/path/' + 'a'.repeat(255), // Very long filename
			'/allowed/path/' + 'a'.repeat(1000), // Extremely long filename
			'/allowed/path/' + 'a/'.repeat(50) + 'file.txt', // Many nested directories
		];

		for (const path of edge_case_paths) {
			expect(safe_fs.is_path_allowed(path)).toBe(true);

			// Mock a successful read to test the full flow
			vi.mocked(fs.readFile).mockReset();
			vi.mocked(fs.readFile).mockResolvedValueOnce('content' as any);

			const content = await safe_fs.read_file(path);
			expect(content).toBe('content');
		}
	});
});

describe('Safe_Fs - Advanced Use Cases', () => {
	test('should handle complex workflows with multiple operations', async () => {
		const safe_fs = create_test_instance();

		// Setup a complex workflow: create dir, write file, read file, copy file, delete original
		vi.mocked(fs.mkdir).mockResolvedValueOnce(undefined);
		vi.mocked(fs.writeFile).mockResolvedValueOnce();
		vi.mocked(fs.readFile).mockResolvedValueOnce('file content' as any);
		vi.mocked(fs.copyFile).mockResolvedValueOnce();
		vi.mocked(fs.rm).mockResolvedValueOnce();

		// Execute workflow
		const workflow_dir = '/allowed/path/workflow';
		const source_file = `${workflow_dir}/source.txt`;
		const dest_file = `${workflow_dir}/dest.txt`;

		await safe_fs.mkdir(workflow_dir);
		await safe_fs.write_file(source_file, 'original content');
		const content = await safe_fs.read_file(source_file);
		await safe_fs.copy_file(source_file, dest_file);
		await safe_fs.rm(source_file);

		// Verify all operations happened with correct parameters
		expect(content).toBe('file content');
		expect(fs.mkdir).toHaveBeenCalledWith(workflow_dir, undefined);
		expect(fs.writeFile).toHaveBeenCalledWith(source_file, 'original content', 'utf8');
		expect(fs.readFile).toHaveBeenCalledWith(source_file, 'utf8');
		expect(fs.copyFile).toHaveBeenCalledWith(source_file, dest_file, undefined);
		expect(fs.rm).toHaveBeenCalledWith(source_file, undefined);
	});

	test('should handle concurrent operations correctly', async () => {
		const safe_fs = create_test_instance();

		// Setup mocks
		vi.mocked(fs.readFile)
			.mockResolvedValueOnce('content1' as any)
			.mockResolvedValueOnce('content2' as any);

		vi.mocked(fs.writeFile).mockResolvedValueOnce().mockResolvedValueOnce();

		// Run concurrent operations
		const [result1, result2] = await Promise.all([
			safe_fs.read_file('/allowed/path/file1.txt'),
			safe_fs.read_file('/allowed/path/file2.txt'),
		]);

		await Promise.all([
			safe_fs.write_file('/allowed/path/output1.txt', 'data1'),
			safe_fs.write_file('/allowed/path/output2.txt', 'data2'),
		]);

		// Verify results
		expect(result1).toBe('content1');
		expect(result2).toBe('content2');
		expect(fs.readFile).toHaveBeenCalledTimes(2);
		expect(fs.writeFile).toHaveBeenCalledTimes(2);
		expect(fs.writeFile).toHaveBeenCalledWith('/allowed/path/output1.txt', 'data1', 'utf8');
		expect(fs.writeFile).toHaveBeenCalledWith('/allowed/path/output2.txt', 'data2', 'utf8');
	});

	test('should handle sequential operations that build on each other', async () => {
		const safe_fs = create_test_instance();

		// Create a more complex scenario with sequential dependent operations
		vi.mocked(fs.mkdir).mockResolvedValue(undefined);
		vi.mocked(fs.writeFile).mockResolvedValue();
		vi.mocked(fs.readdir).mockResolvedValue(['file1.txt', 'file2.txt'] as any);
		vi.mocked(fs.readFile)
			.mockResolvedValueOnce('content1' as any)
			.mockResolvedValueOnce('content2' as any);
		vi.mocked(fs.rm).mockResolvedValue();

		// Execute a complex sequential workflow
		const base_dir = '/allowed/path/project';
		await safe_fs.mkdir(base_dir);

		// Create some files
		await safe_fs.write_file(`${base_dir}/file1.txt`, 'content1');
		await safe_fs.write_file(`${base_dir}/file2.txt`, 'content2');

		// List directory and read each file
		const files = await safe_fs.readdir(base_dir);
		const contents = [];

		// Read content of each file in directory
		for (const file of files) {
			const file_path = `${base_dir}/${file}`;
			const content = await safe_fs.read_file(file_path);
			contents.push(content);
		}

		// Clean up
		await safe_fs.rm(base_dir, {recursive: true});

		// Verify everything worked as expected
		expect(contents).toEqual(['content1', 'content2']);
		expect(fs.mkdir).toHaveBeenCalledWith(base_dir, undefined);
		expect(fs.readdir).toHaveBeenCalledWith(base_dir, undefined);
		expect(fs.rm).toHaveBeenCalledWith(base_dir, {recursive: true});
	});
});

describe('Safe_Fs - Directory Path Trailing Slash Handling', () => {
	test('should ensure all allowed paths have trailing slashes internally', () => {
		// Create instances with a mix of slashed and unslashed paths
		const paths_with_mix = ['/path1', '/path2/', '/path3/subdir', '/path4/subdir/'];
		const safe_fs = new Safe_Fs(paths_with_mix);

		// All paths should have trailing slashes internally
		for (const path of safe_fs.allowed_paths) {
			expect(path.endsWith('/')).toBe(true);
		}

		// Original array should be unmodified
		expect(paths_with_mix).toEqual(['/path1', '/path2/', '/path3/subdir', '/path4/subdir/']);
	});

	test('should correctly validate paths regardless of trailing slashes', () => {
		// Create Safe_Fs with paths that don't have trailing slashes
		const safe_fs = new Safe_Fs(['/dir1', '/dir2/subdir']);

		// These paths should all be allowed, with or without trailing slashes
		const valid_paths = [
			'/dir1',
			'/dir1/',
			'/dir1/file.txt',
			'/dir2/subdir',
			'/dir2/subdir/',
			'/dir2/subdir/file.txt',
		];

		for (const path of valid_paths) {
			expect(safe_fs.is_path_allowed(path)).toBe(true);
		}

		// These paths should all be rejected
		const invalid_paths = [
			'/dir', // Parent of allowed path
			'/dir1_extra', // Similar name
			'/dir2', // Parent directory only
			'/dir2/other', // Different subdirectory
		];

		for (const path of invalid_paths) {
			expect(safe_fs.is_path_allowed(path)).toBe(false);
		}
	});

	test('should handle filesystem operations consistently with or without trailing slashes', async () => {
		// Create Safe_Fs with a mix of slashed and unslashed paths
		const safe_fs = new Safe_Fs(['/allowed/path', '/other/dir/']);

		// Mock filesystem operations
		vi.mocked(fs.readFile).mockResolvedValue('content' as any);
		vi.mocked(fs.writeFile).mockResolvedValue();

		// Test path variations
		const test_paths = [
			'/allowed/path',
			'/allowed/path/',
			'/allowed/path/file.txt',
			'/other/dir',
			'/other/dir/',
			'/other/dir/file.txt',
		];

		for (const path of test_paths) {
			vi.mocked(fs.readFile).mockClear();

			// Read operations should work with all variations
			await safe_fs.read_file(path);
			expect(fs.readFile).toHaveBeenCalledWith(path, 'utf8');

			// Write operations should also work
			vi.mocked(fs.writeFile).mockClear();
			await safe_fs.write_file(path, 'content');
			expect(fs.writeFile).toHaveBeenCalledWith(path, 'content', 'utf8');
		}
	});

	test('should maintain path boundaries correctly with trailing slash normalization', async () => {
		// Create Safe_Fs with specific paths
		const safe_fs = new Safe_Fs(['/data/users', '/data/public/']);

		// These paths should be valid
		const valid_paths = [
			'/data/users',
			'/data/users/',
			'/data/users/profile.txt',
			'/data/public',
			'/data/public/',
			'/data/public/index.html',
		];

		// These should be invalid - testing boundary conditions
		const invalid_paths = [
			'/data', // Parent directory
			'/data/user', // Similar but different directory
			'/data/users_archive', // Directory with similar prefix
			'/data/public_html', // Directory with similar prefix
			'/data/users/../private', // Traversal attempt that would normalize outside
		];

		// Test valid paths
		for (const path of valid_paths) {
			expect(safe_fs.is_path_allowed(path)).toBe(true);
		}

		// Test invalid paths
		for (const path of invalid_paths) {
			expect(safe_fs.is_path_allowed(path)).toBe(false);
			await expect(safe_fs.read_file(path)).rejects.toThrow('Path is not allowed');
		}
	});

	test('should continue to handle root directory as a special case', async () => {
		// Create Safe_Fs with root directory
		const safe_fs = new Safe_Fs(['/']);

		// All paths should be allowed when root is specified
		const test_paths = ['/', '/etc', '/usr/bin', '/home/user/file.txt'];

		for (const path of test_paths) {
			expect(safe_fs.is_path_allowed(path)).toBe(true);

			// Mock successful read
			vi.mocked(fs.readFile).mockReset();
			vi.mocked(fs.readFile).mockResolvedValueOnce('content' as any);

			const content = await safe_fs.read_file(path);
			expect(content).toBe('content');
		}
	});
});
