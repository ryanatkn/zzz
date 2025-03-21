// @vitest-environment jsdom

import {test, expect, vi} from 'vitest';

import {Diskfile_History} from '$lib/diskfile_history.svelte.js';
import {Diskfile_Path} from '$lib/diskfile_types.js';
import {Uuid} from '$lib/zod_helpers.js';

// Mock timestamp for consistent testing
const MOCK_TIMESTAMP = 1234567890;

// Create a mock zzz object
const create_mock_zzz = () => {
	return {
		time: {
			now: vi.fn(() => MOCK_TIMESTAMP),
			get_date: vi.fn(() => new Date(MOCK_TIMESTAMP)),
		},
		registry: {
			instantiate: vi.fn(),
		},
		cells: new Map(),
	};
};

test('Diskfile_History - initialization', () => {
	const mock_zzz = create_mock_zzz();
	const path = Diskfile_Path.parse('/path/to/file.txt');

	const history = new Diskfile_History({
		zzz: mock_zzz as any,
		json: {
			path,
			entries: [],
		},
	});

	expect(history.path).toBe(path);
	expect(history.entries).toEqual([]);
	expect(history.max_entries).toBe(100);
	expect(history.current_entry).toBe(null);
});

test('Diskfile_History - add_entry generates UUID and uses current time', () => {
	const mock_zzz = create_mock_zzz();
	const path = Diskfile_Path.parse('/path/to/file.txt');

	const history = new Diskfile_History({
		zzz: mock_zzz as any,
		json: {
			path,
			entries: [],
		},
	});

	// Add an entry without specifying a timestamp
	const entry = history.add_entry('test content');

	// Check that a UUID was generated and time.now was used
	expect(history.entries.length).toBe(1);
	expect(history.entries[0]).toEqual({
		id: expect.any(String),
		created: expect.any(Number),
		content: 'test content',
		is_disk_change: false,
	});

	// Verify the returned entry matches what was added
	expect(entry).toEqual(history.entries[0]);
});

test('Diskfile_History - add_entry with custom timestamp', () => {
	const mock_zzz = create_mock_zzz();
	const path = Diskfile_Path.parse('/path/to/file.txt');

	const history = new Diskfile_History({
		zzz: mock_zzz as any,
		json: {
			path,
			entries: [],
		},
	});

	const custom_timestamp = 9876543210;

	// Add an entry with a specific timestamp
	const entry = history.add_entry('test content', {
		created: custom_timestamp,
	});

	// Check that the custom timestamp was used
	expect(history.entries.length).toBe(1);
	expect(history.entries[0].created).toBe(custom_timestamp);
	expect(entry.created).toBe(custom_timestamp);
});

test('Diskfile_History - add_entry with options', () => {
	const mock_zzz = create_mock_zzz();
	const path = Diskfile_Path.parse('/path/to/file.txt');

	const history = new Diskfile_History({
		zzz: mock_zzz as any,
		json: {
			path,
			entries: [],
		},
	});

	// Add an entry with all options
	const entry = history.add_entry('test content', {
		created: MOCK_TIMESTAMP,
		is_disk_change: true,
		label: 'Test Label',
	});

	// Check that all options were applied correctly
	expect(history.entries.length).toBe(1);
	expect(history.entries[0]).toEqual({
		id: expect.any(String),
		created: MOCK_TIMESTAMP,
		content: 'test content',
		is_disk_change: true,
		label: 'Test Label',
	});

	// Verify returned entry has the label
	expect(entry.label).toBe('Test Label');
});

test('Diskfile_History - add_entry skips duplicate back-to-back entries', () => {
	const mock_zzz = create_mock_zzz();
	const path = Diskfile_Path.parse('/path/to/file.txt');

	// Create a UUID for our test entry
	const entry_id = Uuid.parse(undefined);

	const history = new Diskfile_History({
		zzz: mock_zzz as any,
		json: {
			path,
			entries: [
				{
					id: entry_id,
					created: MOCK_TIMESTAMP - 1000,
					content: 'test content',
					is_disk_change: false,
				},
			],
		},
	});

	// Try to add an entry with the same content
	const duplicate_entry = history.add_entry('test content');

	// Check that no new entry was added and the original entry was returned
	expect(history.entries.length).toBe(1);
	expect(history.entries[0].created).toBe(MOCK_TIMESTAMP - 1000);
	expect(duplicate_entry.id).toBe(entry_id);
});

test('Diskfile_History - add_entry trims history when it exceeds max_entries', () => {
	const mock_zzz = create_mock_zzz();
	const path = Diskfile_Path.parse('/path/to/file.txt');

	// Create history with small max_entries
	const history = new Diskfile_History({
		zzz: mock_zzz as any,
		json: {
			path,
			entries: [],
			max_entries: 3,
		},
	});

	// Add more entries than the maximum
	history.add_entry('content 1', {created: 1000});
	history.add_entry('content 2', {created: 2000});
	history.add_entry('content 3', {created: 3000});
	history.add_entry('content 4', {created: 4000});

	// Check that only the most recent entries are kept
	expect(history.entries.length).toBe(3);
	expect(history.entries[0].content).toBe('content 2');
	expect(history.entries[1].content).toBe('content 3');
	expect(history.entries[2].content).toBe('content 4');
});

test('Diskfile_History - find_entry_by_id returns the correct entry', () => {
	const mock_zzz = create_mock_zzz();
	const path = Diskfile_Path.parse('/path/to/file.txt');

	// Create test entries with IDs
	const entry1_id = Uuid.parse(undefined);
	const entry2_id = Uuid.parse(undefined);
	const entry3_id = Uuid.parse(undefined);

	const entries = [
		{id: entry1_id, created: 1000, content: 'content 1', is_disk_change: false},
		{id: entry2_id, created: 2000, content: 'content 2', is_disk_change: true},
		{id: entry3_id, created: 3000, content: 'content 3', is_disk_change: false},
	];

	const history = new Diskfile_History({
		zzz: mock_zzz as any,
		json: {
			path,
			entries,
		},
	});

	// Find existing entry
	const found = history.find_entry_by_id(entry2_id);

	// Check result
	expect(found).toEqual(entries[1]);
	expect(found?.content).toBe('content 2');

	// Try to find non-existent entry
	const not_found = history.find_entry_by_id(Uuid.parse(undefined));
	expect(not_found).toBeUndefined();
});

test('Diskfile_History - get_content returns content from entry', () => {
	const mock_zzz = create_mock_zzz();
	const path = Diskfile_Path.parse('/path/to/file.txt');

	// Create test entries with IDs
	const entry1_id = Uuid.parse(undefined);
	const entry2_id = Uuid.parse(undefined);

	const entries = [
		{id: entry1_id, created: 1000, content: 'content 1', is_disk_change: false},
		{id: entry2_id, created: 2000, content: 'content 2', is_disk_change: true},
	];

	const history = new Diskfile_History({
		zzz: mock_zzz as any,
		json: {
			path,
			entries,
		},
	});

	// Get content from existing entry
	expect(history.get_content(entry1_id)).toBe('content 1');

	// Try to get content from non-existent entry
	expect(history.get_content(Uuid.parse(undefined))).toBeNull();
});

test('Diskfile_History - clear_except_current keeps only most recent entry', () => {
	const mock_zzz = create_mock_zzz();
	const path = Diskfile_Path.parse('/path/to/file.txt');

	const entry1_id = Uuid.parse(undefined);
	const entry2_id = Uuid.parse(undefined);
	const entry3_id = Uuid.parse(undefined);

	const entries = [
		{id: entry1_id, created: 1000, content: 'content 1', is_disk_change: false},
		{id: entry2_id, created: 2000, content: 'content 2', is_disk_change: true},
		{id: entry3_id, created: 3000, content: 'content 3', is_disk_change: false},
	];

	const history = new Diskfile_History({
		zzz: mock_zzz as any,
		json: {
			path,
			entries,
		},
	});

	// Clear history except the most recent entry
	history.clear_except_current();

	// Check that only the most recent entry remains
	expect(history.entries.length).toBe(1);
	expect(history.entries[0].content).toBe('content 3');
	expect(history.entries[0].id).toBe(entry3_id);
});

test('Diskfile_History - clear_except_current does nothing for empty history', () => {
	const mock_zzz = create_mock_zzz();
	const path = Diskfile_Path.parse('/path/to/file.txt');

	const history = new Diskfile_History({
		zzz: mock_zzz as any,
		json: {
			path,
			entries: [],
		},
	});

	// Call clear on empty history
	history.clear_except_current();

	// Check that it's still empty
	expect(history.entries.length).toBe(0);
});

test('Diskfile_History - current_entry provides the most recent entry', () => {
	const mock_zzz = create_mock_zzz();
	const path = Diskfile_Path.parse('/path/to/file.txt');

	const entry1_id = Uuid.parse(undefined);
	const entry2_id = Uuid.parse(undefined);

	const entries = [
		{id: entry1_id, created: 1000, content: 'content 1', is_disk_change: false},
		{id: entry2_id, created: 2000, content: 'content 2', is_disk_change: true},
	];

	const history = new Diskfile_History({
		zzz: mock_zzz as any,
		json: {
			path,
			entries,
		},
	});

	// Check current entry
	expect(history.current_entry).toEqual(entries[1]);
	expect(history.current_entry?.id).toBe(entry2_id);

	// Add a new entry and verify current_entry updates
	const new_entry = history.add_entry('content 3');
	expect(history.current_entry?.content).toBe('content 3');
	expect(history.current_entry?.id).toBe(new_entry.id);
});
