import {test, expect, vi, beforeEach, afterEach} from 'vitest';
import * as fs from 'node:fs';

import {
	is_directory,
	create_dir_in_allowed_dir,
	delete_dir_from_allowed_dir,
	list_dir_in_allowed_dir,
} from '$lib/server/filesystem_helpers.js';

/* eslint-disable @typescript-eslint/no-empty-function */

// Mock filesystem functions to prevent actual file operations
vi.mock('node:fs', () => ({
	writeFileSync: vi.fn(),
	rmSync: vi.fn(),
	rmdirSync: vi.fn(),
	mkdirSync: vi.fn(),
	readdirSync: vi.fn(),
	lstatSync: vi.fn(),
	existsSync: vi.fn(),
}));

// Reset mocks before each test
beforeEach(() => {
	vi.clearAllMocks();
	vi.mocked(fs.existsSync).mockReturnValue(true);
	vi.mocked(fs.lstatSync).mockReturnValue({
		isSymbolicLink: () => false,
		isDirectory: () => true,
	} as any);
});

// Restore mocks after all tests
afterEach(() => {
	vi.restoreAllMocks();
});

// Test data - removed unused variables

test('is_directory - should correctly identify directories', () => {
	// Mock directory
	vi.mocked(fs.lstatSync).mockReturnValueOnce({
		isDirectory: () => true,
		isSymbolicLink: () => false,
	} as any);
	expect(is_directory('/allowed/path')).toBe(true);

	// Mock file (not a directory)
	vi.mocked(fs.lstatSync).mockReturnValueOnce({
		isDirectory: () => false,
		isSymbolicLink: () => false,
	} as any);
	expect(is_directory('/allowed/path/file.txt')).toBe(false);

	// Mock non-existent path
	vi.mocked(fs.existsSync).mockReturnValueOnce(false);
	expect(is_directory('/allowed/nonexistent')).toBe(false);
});

test('create_dir_in_allowed_dir - should create directories in allowed paths', () => {
	const dir_path = '/allowed/path/new_dir';
	const parent_dir = '/allowed/path/';

	const result = create_dir_in_allowed_dir(dir_path, parent_dir);

	expect(result).toBe(true);
	expect(fs.mkdirSync).toHaveBeenCalledWith(dir_path, {recursive: true});
});

test('create_dir_in_allowed_dir - should not create directories outside allowed paths', () => {
	const dir_path = '/not_allowed/path/new_dir';
	const parent_dir = '/allowed/path/';

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	const result = create_dir_in_allowed_dir(dir_path, parent_dir);

	expect(result).toBe(false);
	expect(fs.mkdirSync).not.toHaveBeenCalled();

	console_spy.mockRestore();
});

test('create_dir_in_allowed_dir - should handle filesystem errors gracefully', () => {
	const dir_path = '/allowed/path/error_dir';
	const parent_dir = '/allowed/path/';

	// Mock mkdir to throw error
	vi.mocked(fs.mkdirSync).mockImplementationOnce(() => {
		throw new Error('Permission denied');
	});

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	const result = create_dir_in_allowed_dir(dir_path, parent_dir);

	expect(result).toBe(false);
	expect(fs.mkdirSync).toHaveBeenCalledWith(dir_path, {recursive: true});

	console_spy.mockRestore();
});

test('delete_dir_from_allowed_dir - should delete empty directories in allowed paths', () => {
	const dir_path = '/allowed/path/empty_dir';
	const parent_dir = '/allowed/path/';

	// Mock is_directory to return true
	vi.mocked(fs.lstatSync).mockReturnValue({
		isDirectory: () => true,
		isSymbolicLink: () => false,
	} as any);

	const result = delete_dir_from_allowed_dir(dir_path, parent_dir, false);

	expect(result).toBe(true);
	expect(fs.rmdirSync).toHaveBeenCalledWith(dir_path);
	expect(fs.rmSync).not.toHaveBeenCalled();
});

test('delete_dir_from_allowed_dir - should delete directories recursively when specified', () => {
	const dir_path = '/allowed/path/nested_dir';
	const parent_dir = '/allowed/path/';

	// Mock is_directory to return true
	vi.mocked(fs.lstatSync).mockReturnValue({
		isDirectory: () => true,
		isSymbolicLink: () => false,
	} as any);

	const result = delete_dir_from_allowed_dir(dir_path, parent_dir, true);

	expect(result).toBe(true);
	expect(fs.rmSync).toHaveBeenCalledWith(dir_path, {recursive: true, force: true});
	expect(fs.rmdirSync).not.toHaveBeenCalled();
});

test('delete_dir_from_allowed_dir - should not delete directories outside allowed paths', () => {
	const dir_path = '/not_allowed/path/dir';
	const parent_dir = '/allowed/path/';

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	const result = delete_dir_from_allowed_dir(dir_path, parent_dir);

	expect(result).toBe(false);
	expect(fs.rmdirSync).not.toHaveBeenCalled();
	expect(fs.rmSync).not.toHaveBeenCalled();

	console_spy.mockRestore();
});

test('delete_dir_from_allowed_dir - should not delete non-directories', () => {
	const file_path = '/allowed/path/file.txt';
	const parent_dir = '/allowed/path/';

	// Mock is_directory to return false (it's a file)
	vi.mocked(fs.lstatSync).mockReturnValue({
		isDirectory: () => false,
		isSymbolicLink: () => false,
	} as any);

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	const result = delete_dir_from_allowed_dir(file_path, parent_dir);

	expect(result).toBe(false);
	expect(fs.rmdirSync).not.toHaveBeenCalled();
	expect(fs.rmSync).not.toHaveBeenCalled();

	console_spy.mockRestore();
});

test('list_dir_in_allowed_dir - should list directory contents in allowed paths', () => {
	const dir_path = '/allowed/path/list_dir';
	const parent_dir = '/allowed/path/';

	// Use Dirent objects instead of strings
	const dir_entries = [
		{name: 'file1.txt', isDirectory: () => false},
		{name: 'file2.txt', isDirectory: () => false},
		{name: 'subdir', isDirectory: () => true},
	] as unknown as Array<fs.Dirent>;

	// Mock readdirSync to return Dirent objects
	vi.mocked(fs.readdirSync).mockReturnValueOnce(dir_entries);

	// Mock is_directory to return true
	vi.mocked(fs.lstatSync).mockReturnValue({
		isDirectory: () => true,
		isSymbolicLink: () => false,
	} as any);

	const result = list_dir_in_allowed_dir(dir_path, parent_dir);

	// Expect the result to be string names from the Dirent objects
	expect(result).toEqual(['file1.txt', 'file2.txt', 'subdir']);
	expect(fs.readdirSync).toHaveBeenCalledWith(dir_path);
});

test('list_dir_in_allowed_dir - should not list directories outside allowed paths', () => {
	const dir_path = '/not_allowed/path/dir';
	const parent_dir = '/allowed/path/';

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	const result = list_dir_in_allowed_dir(dir_path, parent_dir);

	expect(result).toBeNull();
	expect(fs.readdirSync).not.toHaveBeenCalled();

	console_spy.mockRestore();
});

test('list_dir_in_allowed_dir - should not list non-directories', () => {
	const file_path = '/allowed/path/file.txt';
	const parent_dir = '/allowed/path/';

	// Mock is_directory to return false (it's a file)
	vi.mocked(fs.lstatSync).mockReturnValue({
		isDirectory: () => false,
		isSymbolicLink: () => false,
	} as any);

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	const result = list_dir_in_allowed_dir(file_path, parent_dir);

	expect(result).toBeNull();
	expect(fs.readdirSync).not.toHaveBeenCalled();

	console_spy.mockRestore();
});

test('list_dir_in_allowed_dir - should handle filesystem errors gracefully', () => {
	const dir_path = '/allowed/path/error_dir';
	const parent_dir = '/allowed/path/';

	// Mock is_directory to return true
	vi.mocked(fs.lstatSync).mockReturnValue({
		isDirectory: () => true,
		isSymbolicLink: () => false,
	} as any);

	// Mock readdirSync to throw error
	vi.mocked(fs.readdirSync).mockImplementationOnce(() => {
		throw new Error('Permission denied');
	});

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	const result = list_dir_in_allowed_dir(dir_path, parent_dir);

	expect(result).toBeNull();
	expect(fs.readdirSync).toHaveBeenCalledWith(dir_path);

	console_spy.mockRestore();
});

test('security - all directory operations should respect symlink checks', () => {
	const symlink_dir = '/allowed/path/symlink_dir';
	const parent_dir = '/allowed/path/';

	// Mock as symlink
	vi.mocked(fs.lstatSync).mockReturnValue({
		isDirectory: () => true,
		isSymbolicLink: () => true,
	} as any);

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	// Test create
	expect(create_dir_in_allowed_dir(symlink_dir, parent_dir)).toBe(false);

	// Test delete
	expect(delete_dir_from_allowed_dir(symlink_dir, parent_dir)).toBe(false);

	// Test list
	expect(list_dir_in_allowed_dir(symlink_dir, parent_dir)).toBeNull();

	console_spy.mockRestore();
});

test('security - all directory operations should prevent path traversal', () => {
	const traversal_path = '/allowed/path/../../../etc/sensitive';
	const parent_dir = '/allowed/path/';

	// Mock console.error to avoid cluttering test output
	const console_spy = vi.spyOn(console, 'error').mockImplementation(() => {});

	// Test create
	expect(create_dir_in_allowed_dir(traversal_path, parent_dir)).toBe(false);

	// Test delete
	expect(delete_dir_from_allowed_dir(traversal_path, parent_dir)).toBe(false);

	// Test list
	expect(list_dir_in_allowed_dir(traversal_path, parent_dir)).toBeNull();

	console_spy.mockRestore();
});
