// @vitest-environment jsdom

import {test, expect, beforeEach} from 'vitest';

import {Diskfile_History} from '$lib/diskfile_history.svelte.js';
import {Diskfile_Path} from '$lib/diskfile_types.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Zzz} from '$lib/zzz.svelte.js';
import {monkeypatch_zzz_for_tests} from '$lib/test_helpers.js';

// Test data
const TEST_PATH = Diskfile_Path.parse('/path/to/file.txt');
const TEST_CONTENT = 'Test content';

// Test suite
let zzz: Zzz;
let history: Diskfile_History;

beforeEach(() => {
	// Create a real Zzz instance for each test
	zzz = monkeypatch_zzz_for_tests(new Zzz());

	// Create a fresh history instance for each test with the real Zzz instance
	history = new Diskfile_History({
		zzz,
		json: {
			path: TEST_PATH,
			entries: [],
		},
	});
});

test('Diskfile_History - initialization creates empty history', () => {
	expect(history.path).toBe(TEST_PATH);
	expect(history.entries).toEqual([]);
	expect(history.max_entries).toBe(100);
	expect(history.current_entry).toBe(null);
});

test('Diskfile_History - add_entry creates new entry', () => {
	const entry = history.add_entry(TEST_CONTENT);

	// Verify entry was created with proper structure
	expect(history.entries.length).toBe(1);
	expect(entry.content).toBe(TEST_CONTENT);
	expect(entry.id).toBeDefined();
	expect(typeof entry.created).toBe('number');
	expect(entry.is_disk_change).toBe(false);
	expect(entry.is_unsaved_edit).toBe(false);
});

test('Diskfile_History - add_entry with custom options', () => {
	const custom_timestamp = Date.now() - 1000;

	const entry = history.add_entry(TEST_CONTENT, {
		created: custom_timestamp,
		is_disk_change: true,
		is_unsaved_edit: true,
		label: 'Custom Label',
	});

	// Verify all options were applied
	expect(entry.created).toBe(custom_timestamp);
	expect(entry.is_disk_change).toBe(true);
	expect(entry.is_unsaved_edit).toBe(true);
	expect(entry.label).toBe('Custom Label');
});

test('Diskfile_History - entries are sorted by creation time', () => {
	// Add entries with timestamps in non-chronological order
	const time3 = Date.now();
	const time2 = time3 - 1000;
	const time1 = time2 - 1000;

	history.add_entry('content 2', {created: time2});
	history.add_entry('content 3', {created: time3});
	history.add_entry('content 1', {created: time1});

	// Verify entries are sorted newest first
	expect(history.entries.length).toBe(3);
	expect(history.entries[0].content).toBe('content 3');
	expect(history.entries[1].content).toBe('content 2');
	expect(history.entries[2].content).toBe('content 1');
});

test('Diskfile_History - current_entry returns most recent entry', () => {
	// Add entries
	history.add_entry('first entry');
	const latest = history.add_entry('latest entry');

	// Verify current_entry points to most recent
	expect(history.current_entry).toBe(history.entries[0]);
	expect(history.current_entry).toEqual(latest);
});

test('Diskfile_History - add_entry skips duplicate content back-to-back', () => {
	// Add initial entry
	const first = history.add_entry(TEST_CONTENT);

	// Add duplicate entry
	const duplicate = history.add_entry(TEST_CONTENT);

	// Verify no new entry was added and original was returned
	expect(history.entries.length).toBe(1);
	expect(duplicate).toEqual(first);
	expect(duplicate.id).toBe(first.id);
});

test('Diskfile_History - add_entry respects max_entries limit', () => {
	// Create history with small limit
	const small_history = new Diskfile_History({
		zzz,
		json: {
			path: TEST_PATH,
			entries: [],
		},
	});
	small_history.max_entries = 3;

	// Add more entries than the maximum
	small_history.add_entry('content 1', {created: Date.now() - 3000});
	small_history.add_entry('content 2', {created: Date.now() - 2000});
	small_history.add_entry('content 3', {created: Date.now() - 1000});
	small_history.add_entry('content 4', {created: Date.now()});

	// Verify only the most recent entries were kept
	expect(small_history.entries.length).toBe(3);
	expect(small_history.entries[0].content).toBe('content 4');
	expect(small_history.entries[1].content).toBe('content 3');
	expect(small_history.entries[2].content).toBe('content 2');
});

test('Diskfile_History - find_entry_by_id finds correct entry', () => {
	// Add some entries
	history.add_entry('content 1');
	const entry2 = history.add_entry('content 2');
	history.add_entry('content 3');

	// Find an entry by ID
	const found = history.find_entry_by_id(entry2.id);

	// Verify the right entry was found
	expect(found).toBeDefined();
	expect(found!.id).toBe(entry2.id);
	expect(found!.content).toBe('content 2');

	// Verify non-existent ID returns undefined
	const unknown_id = Uuid.parse(undefined);
	expect(history.find_entry_by_id(unknown_id)).toBeUndefined();
});

test('Diskfile_History - get_content returns content from entry', () => {
	// Add an entry
	const entry = history.add_entry('specific content');

	// Get content by ID
	const content = history.get_content(entry.id);

	// Verify content was retrieved
	expect(content).toBe('specific content');

	// Verify non-existent ID returns null
	const unknown_id = Uuid.parse(undefined);
	expect(history.get_content(unknown_id)).toBeNull();
});

test('Diskfile_History - clear_except_current keeps only newest entry', () => {
	// Add multiple entries
	history.add_entry('old content 1');
	history.add_entry('old content 2');
	const newest = history.add_entry('newest content');

	// Verify we have multiple entries
	expect(history.entries.length).toBe(3);

	// Clear all except current
	history.clear_except_current();

	// Verify only newest remains
	expect(history.entries.length).toBe(1);
	expect(history.entries[0].id).toBe(newest.id);
	expect(history.entries[0].content).toBe('newest content');
});

test('Diskfile_History - clear_except_current handles empty history', () => {
	// Start with empty history
	expect(history.entries.length).toBe(0);

	// Call clear - should not error
	history.clear_except_current();

	// Should still be empty
	expect(history.entries.length).toBe(0);
});

test('Diskfile_History - add_entry handles is_unsaved_edit flag', () => {
	// Add entry with current edit flag
	const entry = history.add_entry(TEST_CONTENT, {
		is_unsaved_edit: true,
	});

	// Verify flag was set
	expect(entry.is_unsaved_edit).toBe(true);
	expect(history.entries[0].is_unsaved_edit).toBe(true);
});

test('Diskfile_History - add_entry maintains insertion order with single assignment', () => {
	// Add multiple entries
	const before_length = history.entries.length;

	// Get initial entries array reference
	const initial_entries = history.entries;

	// Add an entry
	history.add_entry(TEST_CONTENT);

	// Verify entries array was replaced, not mutated in place
	expect(history.entries).not.toBe(initial_entries);
	expect(history.entries.length).toBe(before_length + 1);
});
