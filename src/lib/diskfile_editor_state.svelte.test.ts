// @vitest-environment jsdom

import {test, expect, beforeEach} from 'vitest';

import {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
import {Diskfile_Path} from '$lib/diskfile_types.js';
import {Zzz} from '$lib/zzz.svelte.js';
import {Diskfile} from '$lib/diskfile.svelte.js';

// Constants for testing
const TEST_PATH = Diskfile_Path.parse('/path/to/test.txt');
const TEST_CONTENT = 'This is test content';

// Test suite variables
let zzz: Zzz;
let test_diskfile: Diskfile;
let editor_state: Diskfile_Editor_State;

beforeEach(() => {
	// Create a real Zzz instance for each test
	zzz = new Zzz();

	// Create a real diskfile through the registry
	test_diskfile = zzz.registry.instantiate('Diskfile', {
		path: TEST_PATH,
		content: TEST_CONTENT,
	});

	// Create the editor state with real components
	editor_state = new Diskfile_Editor_State({
		zzz,
		diskfile: test_diskfile,
	});
});

// BASIC FUNCTIONALITY TESTS

test('Editor state initializes with correct values', () => {
	expect(editor_state.original_content).toBe(TEST_CONTENT);
	expect(editor_state.updated_content).toBe(TEST_CONTENT);
	expect(editor_state.has_changes).toBe(false);
	expect(editor_state.content_was_modified_by_user).toBe(false);
	expect(editor_state.unsaved_edit_entry_id).toBeNull();

	// Selected history entry should be initialized to the current entry
	const history = zzz.maybe_get_diskfile_history(TEST_PATH);
	expect(history).toBeDefined();
	expect(history!.entries.length).toBe(1);
	expect(editor_state.selected_history_entry_id).toBe(history!.entries[0].id);
	expect(history!.entries[0].content).toBe(TEST_CONTENT);
});

test('Updating content creates an unsaved entry and updates selection', () => {
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;
	const initial_count = history.entries.length;

	const new_content = 'Modified content';
	editor_state.updated_content = new_content;

	// Verify state changes
	expect(editor_state.updated_content).toBe(new_content);
	expect(editor_state.has_changes).toBe(true);
	expect(editor_state.content_was_modified_by_user).toBe(true);

	// Check history entry was created
	expect(history.entries.length).toBe(initial_count + 1);

	// Verify unsaved entry
	const unsaved_entry = history.entries[0];
	expect(unsaved_entry.content).toBe(new_content);
	expect(unsaved_entry.is_unsaved_edit).toBe(true);

	// Verify tracking IDs point correctly
	expect(editor_state.unsaved_edit_entry_id).toBe(unsaved_entry.id);
	expect(editor_state.selected_history_entry_id).toBe(unsaved_entry.id);
});

test('Multiple content updates modify the same unsaved entry', () => {
	// Make multiple edits
	editor_state.updated_content = 'First edit';

	// Get initial entry count and the unsaved edit ID
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;
	const initial_entry_count = history.entries.length;
	const edit_entry_id = editor_state.unsaved_edit_entry_id;

	expect(edit_entry_id).not.toBeNull();

	// Make additional edits
	editor_state.updated_content = 'Second edit';
	editor_state.updated_content = 'Third edit';

	// Verify that entry count hasn't changed - we're updating the existing entry
	expect(history.entries.length).toBe(initial_entry_count);

	// Verify the unsaved entry ID remains the same
	expect(editor_state.unsaved_edit_entry_id).toBe(edit_entry_id);

	// Verify the content of the unsaved entry was updated
	const unsaved_entry = history.find_entry_by_id(edit_entry_id!);
	expect(unsaved_entry).toBeDefined();
	expect(unsaved_entry?.content).toBe('Third edit');
});

test('Setting content back to original removes unsaved entry and selects current entry', () => {
	// First make an edit
	editor_state.updated_content = 'Changed content';

	// Verify we have an unsaved entry
	expect(editor_state.unsaved_edit_entry_id).not.toBeNull();

	// Get the history entry count and ID
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;
	const initial_entry_count = history.entries.length;
	const edit_entry_id = editor_state.unsaved_edit_entry_id;

	// Now set content back to original
	editor_state.updated_content = TEST_CONTENT;

	// Verify unsaved entry is cleared
	expect(editor_state.unsaved_edit_entry_id).toBeNull();

	// Verify selection points to an entry (not testing exact ID as it may vary)
	expect(editor_state.selected_history_entry_id).not.toBeNull();

	// The selected entry should be in the history
	const selected_entry = history.find_entry_by_id(editor_state.selected_history_entry_id!);
	expect(selected_entry).not.toBeUndefined();

	// Verify the unsaved entry was removed from history
	expect(history.entries.length).toBe(initial_entry_count - 1);
	expect(history.find_entry_by_id(edit_entry_id!)).toBeUndefined();
});

// HISTORY INTERACTION TESTS

test('set_content_from_history loads content and updates selection', () => {
	// Create history entries
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;

	// Initial history entries (will already have one from initialization)
	const initial_selection = editor_state.selected_history_entry_id;
	expect(initial_selection).not.toBeNull();

	const entry1 = history.add_entry('History content 1');
	const entry2 = history.add_entry('History content 2');

	// Select first entry
	editor_state.set_content_from_history(entry1.id);
	expect(editor_state.selected_history_entry_id).toBe(entry1.id);
	expect(editor_state.updated_content).toBe('History content 1');

	// Select second entry
	editor_state.set_content_from_history(entry2.id);
	expect(editor_state.selected_history_entry_id).toBe(entry2.id);
	expect(editor_state.updated_content).toBe('History content 2');
});

test('Selecting an entry with original content keeps the entry selected', () => {
	// Add an entry with the original content
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;
	const original_entry = history.add_entry(TEST_CONTENT);

	// Select the entry with original content
	editor_state.set_content_from_history(original_entry.id);

	// Verify we're viewing the right content
	expect(editor_state.updated_content).toBe(TEST_CONTENT);

	// Selection should point to the entry we selected
	expect(editor_state.selected_history_entry_id).toBe(original_entry.id);

	// Verify entry still exists in history
	expect(history.find_entry_by_id(original_entry.id)).toBeDefined();
});

test('Editing after selecting a history entry creates a new unsaved entry', () => {
	// Create and select a history entry
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;
	const entry = history.add_entry('History content');

	// Select the entry
	editor_state.set_content_from_history(entry.id);
	expect(editor_state.selected_history_entry_id).toBe(entry.id);
	expect(editor_state.unsaved_edit_entry_id).toBeNull();

	// Edit the content
	editor_state.updated_content = 'Modified history content';

	// A new unsaved entry should be created
	expect(editor_state.unsaved_edit_entry_id).not.toBeNull();
	expect(editor_state.unsaved_edit_entry_id).not.toBe(entry.id);

	// Selected entry should match the unsaved entry
	expect(editor_state.selected_history_entry_id).toBe(editor_state.unsaved_edit_entry_id);

	// The original history entry should remain unchanged
	const original_entry = history.find_entry_by_id(entry.id);
	expect(original_entry).toBeDefined();
	expect(original_entry?.content).toBe('History content');
	expect(original_entry?.is_unsaved_edit).toBe(false);

	// Verify the new entry was created with the modified content
	const unsaved_entry = history.find_entry_by_id(editor_state.unsaved_edit_entry_id!);
	expect(unsaved_entry).toBeDefined();
	expect(unsaved_entry?.content).toBe('Modified history content');
	expect(unsaved_entry?.is_unsaved_edit).toBe(true);
});

test('content_matching_entry_ids properly identifies entries with matching content', () => {
	// Create multiple entries with different content
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;
	const entry1 = history.add_entry('Unique content 1');
	const entry2 = history.add_entry('Duplicate content');
	const entry3 = history.add_entry('Unique content 2');
	const entry4 = history.add_entry('Duplicate content'); // Same as entry2

	// Initially no entries match the current content
	expect(editor_state.content_matching_entry_ids).not.toContain(entry1.id);
	expect(editor_state.content_matching_entry_ids).not.toContain(entry2.id);
	expect(editor_state.content_matching_entry_ids).not.toContain(entry3.id);
	expect(editor_state.content_matching_entry_ids).not.toContain(entry4.id);

	// Set content to something that matches entry2 and entry4
	editor_state.updated_content = 'Duplicate content';

	// Verify entry2 and entry4 are identified as matching
	expect(editor_state.content_matching_entry_ids).toContain(entry2.id);
	expect(editor_state.content_matching_entry_ids).toContain(entry4.id);
	expect(editor_state.content_matching_entry_ids).not.toContain(entry1.id);
	expect(editor_state.content_matching_entry_ids).not.toContain(entry3.id);
});

test('save_changes removes unsaved entries and creates a new saved entry', () => {
	// Create multiple unsaved edits
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;

	// Record starting state
	const starting_count = history.entries.length;
	expect(starting_count).toBe(1); // Only the original entry should exist

	// Create entry 1 and modify it
	const entry1 = history.add_entry('Entry 1');
	editor_state.set_content_from_history(entry1.id);
	editor_state.updated_content = 'Modified Entry 1';
	const unsaved_id1 = editor_state.unsaved_edit_entry_id;

	// Verify the first unsaved entry was created
	expect(unsaved_id1).not.toBeNull();
	const unsaved_entry1 = history.find_entry_by_id(unsaved_id1!);
	expect(unsaved_entry1).toBeDefined();
	expect(unsaved_entry1!.is_unsaved_edit).toBe(true);

	// Create entry 2 and modify it
	const entry2 = history.add_entry('Entry 2');
	editor_state.set_content_from_history(entry2.id);
	editor_state.updated_content = 'Modified Entry 2';
	const unsaved_id2 = editor_state.unsaved_edit_entry_id;

	// Verify the second unsaved entry was created
	expect(unsaved_id2).not.toBeNull();
	const unsaved_entry2 = history.find_entry_by_id(unsaved_id2!);
	expect(unsaved_entry2).toBeDefined();
	expect(unsaved_entry2!.is_unsaved_edit).toBe(true);

	// Get total entries before save
	const entry_count_before_save = history.entries.length;
	expect(entry_count_before_save).toBe(starting_count + 4);

	// Save changes
	editor_state.save_changes();

	// All unsaved entries should be removed
	expect(history.find_entry_by_id(unsaved_id1!)).toBeUndefined();
	expect(history.find_entry_by_id(unsaved_id2!)).toBeUndefined();

	// A new saved entry should be created with the current content
	const saved_entry = history.entries[0];
	expect(saved_entry.content).toBe('Modified Entry 2');
	expect(saved_entry.is_unsaved_edit).toBe(false);

	// Selection should point to the new saved entry
	expect(editor_state.selected_history_entry_id).toBe(saved_entry.id);
	expect(editor_state.unsaved_edit_entry_id).toBeNull();
});

// SAVING & DISCARDING TESTS

test('save_changes persists content and clears unsaved state', () => {
	// Make an edit to create an unsaved entry
	editor_state.updated_content = 'Content to save';
	const unsaved_id = editor_state.unsaved_edit_entry_id;

	// Save the changes
	editor_state.save_changes();

	// The unsaved entry ID should be cleared
	expect(editor_state.unsaved_edit_entry_id).toBeNull();

	// The unsaved entry should be removed from history
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;
	expect(history.find_entry_by_id(unsaved_id!)).toBeUndefined();

	// A new saved entry should be created
	const new_entry = history.entries[0];
	expect(new_entry.content).toBe('Content to save');
	expect(new_entry.is_unsaved_edit).toBe(false);
});

// DISK CHANGE TESTS

test('check_disk_changes with no user edits auto-updates content', () => {
	const disk_content = 'Changed on disk';

	// Simulate disk change
	test_diskfile.content = disk_content;

	// Check for disk changes
	editor_state.check_disk_changes();

	// Verify auto-update happened
	expect(editor_state.updated_content).toBe(disk_content);
	expect(editor_state.disk_changed).toBe(false);
	expect(editor_state.last_seen_disk_content).toBe(disk_content);

	// Check history recorded the change
	const history = zzz.maybe_get_diskfile_history(TEST_PATH);
	const latest_entry = history!.entries[0];
	expect(latest_entry.content).toBe(disk_content);
	expect(latest_entry.is_disk_change).toBe(true);

	// Selection should point to the new disk change entry
	expect(editor_state.selected_history_entry_id).toBe(latest_entry.id);
});

test('check_disk_changes with user edits flags a conflict', () => {
	// Make user edits first
	const user_content = 'User edited content';
	editor_state.updated_content = user_content;

	// Simulate disk change
	const disk_content = 'Changed on disk';
	test_diskfile.content = disk_content;

	// Check for disk changes
	editor_state.check_disk_changes();

	// Verify conflict detection
	expect(editor_state.updated_content).toBe(user_content); // User edits preserved
	expect(editor_state.disk_changed).toBe(true);
	expect(editor_state.disk_content).toBe(disk_content);
});

test('accept_disk_changes updates content and preserves original in history', () => {
	// First make user edits
	const user_content = 'User edited content';
	editor_state.updated_content = user_content;

	// Then simulate disk change
	const disk_content = 'Changed content on disk';
	test_diskfile.content = disk_content;

	// Check for disk changes to trigger conflict
	editor_state.check_disk_changes();
	expect(editor_state.disk_changed).toBe(true);

	// Accept disk changes
	editor_state.accept_disk_changes();

	// Content should be updated to disk content
	expect(editor_state.updated_content).toBe(disk_content);
	expect(editor_state.disk_changed).toBe(false);
	expect(editor_state.disk_content).toBeNull();

	// History should have entries for both the user's edits and the disk changes
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;
	const entries_with_user_content = history.entries.filter((e) => e.content === user_content);
	const entries_with_disk_content = history.entries.filter((e) => e.content === disk_content);

	expect(entries_with_user_content.length).toBeGreaterThan(0);
	expect(entries_with_disk_content.length).toBeGreaterThan(0);

	// Disk change entry should be selected
	const disk_entry = entries_with_disk_content.find((e) => e.is_disk_change);
	expect(disk_entry).toBeDefined();
	expect(editor_state.selected_history_entry_id).toBe(disk_entry?.id);
});

test('reject_disk_changes keeps user edits and adds disk change to history', () => {
	// First make user edits
	const user_content = 'User edited content';
	editor_state.updated_content = user_content;

	// Then simulate disk change
	const disk_content = 'Changed content on disk';
	test_diskfile.content = disk_content;

	// Check for disk changes to trigger conflict
	editor_state.check_disk_changes();
	expect(editor_state.disk_changed).toBe(true);

	// Reject disk changes
	editor_state.reject_disk_changes();

	// Content should still be user's content
	expect(editor_state.updated_content).toBe(user_content);
	expect(editor_state.disk_changed).toBe(false);
	expect(editor_state.disk_content).toBeNull();

	// History should contain an entry for the rejected disk content
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;
	const disk_entries = history.entries.filter(
		(e) => e.content === disk_content && e.is_disk_change,
	);
	expect(disk_entries.length).toBeGreaterThan(0);

	// Selection should remain on the user's edit
	const user_entry = history.entries.find((e) => e.content === user_content);
	expect(user_entry).toBeDefined();
	expect(editor_state.selected_history_entry_id).toBe(user_entry?.id);
});

// ADVANCED HISTORY EDITING TESTS

test('Multiple unsaved edits can exist simultaneously in history', () => {
	// Create two entries in history
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;
	const entry1 = history.add_entry('Entry 1');
	const entry2 = history.add_entry('Entry 2');

	// Edit the first entry
	editor_state.set_content_from_history(entry1.id);
	editor_state.updated_content = 'Modified Entry 1';

	// The first entry should now have an unsaved edit with a new ID
	const first_unsaved_id = editor_state.unsaved_edit_entry_id;
	expect(first_unsaved_id).not.toBeNull();
	expect(first_unsaved_id).not.toBe(entry1.id);

	// New unsaved entry should be created and marked accordingly
	const first_unsaved_entry = history.find_entry_by_id(first_unsaved_id!);
	expect(first_unsaved_entry).toBeDefined();
	expect(first_unsaved_entry?.content).toBe('Modified Entry 1');
	expect(first_unsaved_entry?.is_unsaved_edit).toBe(true);

	// Edit the second entry
	editor_state.set_content_from_history(entry2.id);
	editor_state.updated_content = 'Modified Entry 2';

	// The second entry should also have an unsaved edit with a new ID
	const second_unsaved_id = editor_state.unsaved_edit_entry_id;
	expect(second_unsaved_id).not.toBeNull();
	expect(second_unsaved_id).not.toBe(entry2.id);
	expect(second_unsaved_id).not.toBe(first_unsaved_id);

	// Second unsaved entry should also be created and marked accordingly
	const second_unsaved_entry = history.find_entry_by_id(second_unsaved_id!);
	expect(second_unsaved_entry).toBeDefined();
	expect(second_unsaved_entry?.content).toBe('Modified Entry 2');
	expect(second_unsaved_entry?.is_unsaved_edit).toBe(true);

	// First unsaved entry should still exist and be marked as unsaved
	const first_unsaved_entry_after = history.find_entry_by_id(first_unsaved_id!);
	expect(first_unsaved_entry_after).toBeDefined();
	expect(first_unsaved_entry_after?.is_unsaved_edit).toBe(true);
	expect(first_unsaved_entry_after?.content).toBe('Modified Entry 1');

	// Switch back to first unsaved entry
	editor_state.set_content_from_history(first_unsaved_id!);

	// Content should be updated to first unsaved entry's content
	expect(editor_state.updated_content).toBe('Modified Entry 1');

	// Current selection should be the first unsaved entry
	expect(editor_state.selected_history_entry_id).toBe(first_unsaved_id);
	expect(editor_state.unsaved_edit_entry_id).toBe(first_unsaved_id);
});

// EMPTY CONTENT TESTS

test('Empty content values can be selected from history', () => {
	// Create an entry with empty content
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;
	const empty_entry = history.add_entry('');

	// Make sure current selection isn't already the empty entry
	const another_entry = history.add_entry('Some content');
	editor_state.set_content_from_history(another_entry.id);

	// Select the empty entry
	editor_state.set_content_from_history(empty_entry.id);

	// Verify the selection and content
	expect(editor_state.selected_history_entry_id).toBe(empty_entry.id);
	expect(editor_state.updated_content).toBe('');
});

test('Empty content can be created and saved as an unsaved edit', () => {
	// Make sure we're starting with non-empty content
	expect(editor_state.updated_content).not.toBe('');

	// Clear the content by setting to empty string
	editor_state.updated_content = '';

	// Verify an unsaved entry was created with empty content
	expect(editor_state.unsaved_edit_entry_id).not.toBeNull();

	// Get the unsaved entry
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;
	const unsaved_entry = history.find_entry_by_id(editor_state.unsaved_edit_entry_id!);

	// Verify entry has empty content
	expect(unsaved_entry).toBeDefined();
	expect(unsaved_entry!.content).toBe('');
	expect(unsaved_entry!.is_unsaved_edit).toBe(true);
});

// UTILITY FUNCTIONS TESTS

test('clear_history removes all but the most recent entry and clears selection', () => {
	// Add multiple entries
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;
	history.add_entry('History entry 1');
	history.add_entry('History entry 2');

	// Select an entry to verify it gets cleared later
	editor_state.selected_history_entry_id = history.entries[0].id;

	// Verify multiple entries exist
	expect(history.entries.length).toBeGreaterThan(1);

	// Clear history
	editor_state.clear_history();

	// Verify only one entry remains
	expect(history.entries.length).toBe(1);

	// Selection and unsaved state should be cleared
	expect(editor_state.selected_history_entry_id).toBeNull();
	expect(editor_state.unsaved_edit_entry_id).toBeNull();
});

test('update_diskfile handles switching files', () => {
	// Make edits to the current file
	editor_state.updated_content = 'Edited original file';

	// Create a new diskfile
	const new_path = Diskfile_Path.parse('/path/to/another.txt');
	const new_content = 'Content of new file';
	const new_diskfile = zzz.registry.instantiate('Diskfile', {
		path: new_path,
		content: new_content,
	});

	// Switch to the new file
	editor_state.update_diskfile(new_diskfile);

	// Verify state was properly reset and updated
	expect(editor_state.diskfile).toBe(new_diskfile);
	expect(editor_state.original_content).toBe(new_content);
	expect(editor_state.updated_content).toBe(new_content);
	expect(editor_state.has_changes).toBe(false);
	expect(editor_state.content_was_modified_by_user).toBe(false);
	expect(editor_state.unsaved_edit_entry_id).toBeNull();

	// Selected entry should be set to the current entry of the new file
	const new_history = zzz.maybe_get_diskfile_history(new_path);
	expect(new_history).toBeDefined();
	expect(editor_state.selected_history_entry_id).toBe(new_history!.current_entry!.id);
});

test('Editing to match existing history entry content selects that entry instead of creating a new one', () => {
	// Create history entries
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;
	const existing_entry = history.add_entry('Existing content');
	const current_entry = history.add_entry('Current content');

	// Select the current entry
	editor_state.set_content_from_history(current_entry.id);
	expect(editor_state.selected_history_entry_id).toBe(current_entry.id);

	// Get initial entry count
	const initial_entry_count = history.entries.length;

	// Edit content to match the existing entry
	editor_state.updated_content = 'Existing content';

	// Verify that the existing entry is now selected
	expect(editor_state.selected_history_entry_id).toBe(existing_entry.id);

	// Verify that no new entry was created
	expect(history.entries.length).toBe(initial_entry_count);

	// Verify that we don't have an unsaved edit entry
	expect(editor_state.unsaved_edit_entry_id).toBeNull();
});

test('Editing to completely new content creates a new unsaved entry', () => {
	// Create history entries
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;
	history.add_entry('Entry 1');
	const entry2 = history.add_entry('Entry 2');

	// Select an entry
	editor_state.set_content_from_history(entry2.id);
	expect(editor_state.selected_history_entry_id).toBe(entry2.id);

	// Get initial entry count
	const initial_entry_count = history.entries.length;

	// Edit to completely new content
	editor_state.updated_content = 'Brand new content';

	// Verify that a new entry was created
	expect(history.entries.length).toBe(initial_entry_count + 1);
	expect(editor_state.unsaved_edit_entry_id).not.toBeNull();

	// Verify the new entry has the new content
	const unsaved_entry = history.find_entry_by_id(editor_state.unsaved_edit_entry_id!);
	expect(unsaved_entry?.content).toBe('Brand new content');
	expect(unsaved_entry?.is_unsaved_edit).toBe(true);
});

test('Editing from a saved entry to match multiple existing entries selects the first matching one', () => {
	// Create history entries with duplicate content
	const history = zzz.maybe_get_diskfile_history(TEST_PATH)!;
	history.add_entry('Duplicate content', {created: Date.now() - 3000});
	const match2 = history.add_entry('Duplicate content', {created: Date.now() - 2000});
	const current = history.add_entry('Current content', {created: Date.now() - 1000});

	// Select the current entry
	editor_state.set_content_from_history(current.id);

	// Edit to match duplicate content
	editor_state.updated_content = 'Duplicate content';

	// Verify that the first matching entry (newest) is selected
	// Since entries are sorted newest first, match2 is first
	expect(editor_state.selected_history_entry_id).toBe(match2.id);

	// Verify no unsaved entry was created
	expect(editor_state.unsaved_edit_entry_id).toBeNull();
});

// RESET TEST

test('reset clears unsaved state and content modifications', () => {
	// First make edits
	editor_state.updated_content = 'Edited content';

	// Verify unsaved entry was created
	expect(editor_state.unsaved_edit_entry_id).not.toBeNull();
	expect(editor_state.content_was_modified_by_user).toBe(true);

	// Reset the editor state
	editor_state.reset();

	// Verify everything was cleared
	expect(editor_state.updated_content).toBe(TEST_CONTENT);
	expect(editor_state.unsaved_edit_entry_id).toBeNull();
	expect(editor_state.content_was_modified_by_user).toBe(false);
	expect(editor_state.selected_history_entry_id).toBeNull();
});

// METRICS/STATS TESTS

test('Editor provides accurate content metrics', () => {
	// Set specific content to test metrics
	const test_metrics_content = 'Test metrics content with tokens.';
	editor_state.updated_content = test_metrics_content;

	// Check length metrics
	expect(editor_state.updated_length).toBe(test_metrics_content.length);
	expect(editor_state.length_diff).toBe(test_metrics_content.length - TEST_CONTENT.length);

	// Check token metrics
	expect(editor_state.updated_tokens.length).toBeGreaterThan(0);
	expect(editor_state.updated_token_count).toBe(editor_state.updated_tokens.length);
	expect(editor_state.token_diff).toBe(
		editor_state.updated_token_count - editor_state.original_token_count,
	);
});
