// @slop Claude Sonnet 3.7

// @vitest-environment jsdom

import {test, expect, beforeEach, describe} from 'vitest';

import {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
import {Diskfile_Path, Serializable_Disknode} from '$lib/diskfile_types.js';
import {Frontend} from '$lib/frontend.svelte.js';
import {Diskfile} from '$lib/diskfile.svelte.js';
import {monkeypatch_zzz_for_tests} from '$lib/test_helpers.js';

// Constants for testing
const TEST_PATH = Diskfile_Path.parse('/path/to/test.txt');
const TEST_DIR = Serializable_Disknode.shape.source_dir.parse('/path/');
const TEST_CONTENT = 'This is test content';

// Test suite variables
let app: Frontend;
let test_diskfile: Diskfile;
let editor_state: Diskfile_Editor_State;

beforeEach(() => {
	// Create a real Zzz instance for each test
	app = monkeypatch_zzz_for_tests(new Frontend());

	// Create a real diskfile through the registry
	test_diskfile = app.diskfiles.add({
		path: TEST_PATH,
		source_dir: TEST_DIR,
		content: TEST_CONTENT,
	});

	// Create the editor state with real components
	editor_state = new Diskfile_Editor_State({
		app,
		diskfile: test_diskfile,
	});
});

describe('unsaved edit creation', () => {
	test('updating content creates an unsaved entry and updates selection', () => {
		// Update content
		const new_content = 'Modified content';
		editor_state.current_content = new_content;

		// Verify an unsaved entry was created
		expect(editor_state.unsaved_edit_entry_id).not.toBeNull();

		// Verify the new entry
		const history = app.get_diskfile_history(TEST_PATH)!;
		const new_entry = history.find_entry_by_id(editor_state.unsaved_edit_entry_id!);

		expect(new_entry).toMatchObject({
			content: new_content,
			is_unsaved_edit: true,
			label: 'Unsaved edit',
		});

		// Selection should match the unsaved entry
		expect(editor_state.selected_history_entry_id).toBe(editor_state.unsaved_edit_entry_id);
	});

	test('multiple content updates modify the same unsaved entry', () => {
		// Make initial edit
		editor_state.current_content = 'First edit';

		// Track the entry id
		const unsaved_id = editor_state.unsaved_edit_entry_id;
		expect(unsaved_id).not.toBeNull();

		// Make additional edits
		editor_state.current_content = 'Second edit';
		editor_state.current_content = 'Third edit';

		// Verify the same entry was updated
		expect(editor_state.unsaved_edit_entry_id).toBe(unsaved_id);

		// Verify the entry content was updated
		const history = app.get_diskfile_history(TEST_PATH)!;
		const updated_entry = history.find_entry_by_id(unsaved_id!);

		expect(updated_entry).toMatchObject({
			content: 'Third edit',
			is_unsaved_edit: true,
		});
	});

	test('setting content back to original removes unsaved entry', () => {
		// Make an edit to create unsaved entry
		editor_state.current_content = 'Edited content';
		const unsaved_id = editor_state.unsaved_edit_entry_id;

		// Set content back to original
		editor_state.current_content = TEST_CONTENT;

		// Verify unsaved entry was removed
		expect(editor_state.unsaved_edit_entry_id).toBeNull();

		// Entry should no longer exist
		const history = app.get_diskfile_history(TEST_PATH)!;
		expect(history.find_entry_by_id(unsaved_id!)).toBeUndefined();
	});

	test('editing to match existing content selects that entry instead of creating new one', () => {
		// Create entries in history
		const history = app.get_diskfile_history(TEST_PATH)!;
		const existing_entry = history.add_entry('Existing content');

		// Edit to match existing content
		editor_state.current_content = 'Existing content';

		// Existing entry should be selected
		expect(editor_state.selected_history_entry_id).toBe(existing_entry.id);
		expect(editor_state.unsaved_edit_entry_id).toBeNull();
	});

	test('editing to match existing unsaved edit selects that entry', () => {
		// Create an unsaved entry
		const history = app.get_diskfile_history(TEST_PATH)!;
		const unsaved_entry = history.add_entry('Unsaved content', {is_unsaved_edit: true});

		// Select a different entry
		const other_entry = history.add_entry('Other content');
		editor_state.set_content_from_history(other_entry.id);

		// Edit to match the unsaved entry
		editor_state.current_content = 'Unsaved content';

		// The existing unsaved entry should be selected
		expect(editor_state.selected_history_entry_id).toBe(unsaved_entry.id);
		expect(editor_state.unsaved_edit_entry_id).toBe(unsaved_entry.id);
	});
});

describe('history navigation', () => {
	test('set_content_from_history loads content and updates selection', () => {
		// Create history entries
		const history = app.get_diskfile_history(TEST_PATH)!;
		const entry1 = history.add_entry('Entry 1');
		const entry2 = history.add_entry('Entry 2');

		// Select first entry
		editor_state.set_content_from_history(entry1.id);

		// Verify selection and content
		expect(editor_state.selected_history_entry_id).toBe(entry1.id);
		expect(editor_state.current_content).toBe('Entry 1');

		// Select second entry
		editor_state.set_content_from_history(entry2.id);

		// Verify selection and content updated
		expect(editor_state.selected_history_entry_id).toBe(entry2.id);
		expect(editor_state.current_content).toBe('Entry 2');
	});

	test('set_content_from_history with unsaved edit sets unsaved_edit_entry_id', () => {
		// Create unsaved entry
		const history = app.get_diskfile_history(TEST_PATH)!;
		const unsaved_entry = history.add_entry('Unsaved content', {is_unsaved_edit: true});

		// Select unsaved entry
		editor_state.set_content_from_history(unsaved_entry.id);

		// Verify both ids are set correctly
		expect(editor_state.selected_history_entry_id).toBe(unsaved_entry.id);
		expect(editor_state.unsaved_edit_entry_id).toBe(unsaved_entry.id);
	});

	test('set_content_from_history with saved entry clears unsaved_edit_entry_id', () => {
		// Create entries
		const history = app.get_diskfile_history(TEST_PATH)!;
		const saved_entry = history.add_entry('Saved content');

		// First select an unsaved entry
		editor_state.current_content = 'Unsaved content';
		expect(editor_state.unsaved_edit_entry_id).not.toBeNull();

		// Now select the saved entry
		editor_state.set_content_from_history(saved_entry.id);

		// Verify unsaved edit id is cleared
		expect(editor_state.selected_history_entry_id).toBe(saved_entry.id);
		expect(editor_state.unsaved_edit_entry_id).toBeNull();
	});

	test('content_matching_entry_ids tracks entries with matching content', () => {
		// Create entries with duplicate content
		const history = app.get_diskfile_history(TEST_PATH)!;
		const entry1 = history.add_entry('Unique content');
		const entry2 = history.add_entry('Duplicate content');
		const entry3 = history.add_entry('Duplicate content');

		// Initial check - current content doesn't match any entry
		expect(editor_state.content_matching_entry_ids).not.toContain(entry1.id);
		expect(editor_state.content_matching_entry_ids).not.toContain(entry2.id);
		expect(editor_state.content_matching_entry_ids).not.toContain(entry3.id);

		// Set content to match duplicates
		editor_state.current_content = 'Duplicate content';

		// Verify matching entries are tracked
		expect(editor_state.content_matching_entry_ids).toContain(entry2.id);
		expect(editor_state.content_matching_entry_ids).toContain(entry3.id);
		expect(editor_state.content_matching_entry_ids).not.toContain(entry1.id);
	});
});

describe('saving history changes', () => {
	test('save_changes persists content and converts unsaved to saved', async () => {
		// Make an edit to create unsaved entry
		editor_state.current_content = 'Content to save';
		expect(editor_state.unsaved_edit_entry_id).not.toBeNull();

		// Save changes
		await editor_state.save_changes();

		// Verify the unsaved flag was cleared
		expect(editor_state.unsaved_edit_entry_id).toBeNull();

		// A new entry should be created with correct properties
		const history = app.get_diskfile_history(TEST_PATH)!;
		const new_saved_entry = history.entries[0];

		expect(new_saved_entry).toMatchObject({
			content: 'Content to save',
			is_unsaved_edit: false,
		});

		// Selection should point to the new entry
		expect(editor_state.selected_history_entry_id).toBe(new_saved_entry.id);
	});

	test('save_changes with no changes returns false', async () => {
		// Don't make any changes
		expect(editor_state.has_changes).toBe(false);

		// Try to save
		const result = await editor_state.save_changes();

		// Verify nothing was saved
		expect(result).toBe(false);
	});

	test('save_changes updates the diskfile content', async () => {
		// Make an edit
		editor_state.current_content = 'New saved content';

		// Save changes
		await editor_state.save_changes();

		// Verify diskfile was updated
		expect(test_diskfile.content).toBe('New saved content');

		// Verify last_seen_disk_content was updated
		expect(editor_state.last_seen_disk_content).toBe('New saved content');
	});
});

describe('managing unsaved edits', () => {
	test('multiple unsaved edits can exist simultaneously', () => {
		// Create two base entries
		const history = app.get_diskfile_history(TEST_PATH)!;
		const entry1 = history.add_entry('Base 1');
		const entry2 = history.add_entry('Base 2');

		// Edit first entry
		editor_state.set_content_from_history(entry1.id);
		editor_state.current_content = 'Modified 1';
		const unsaved1_id = editor_state.unsaved_edit_entry_id;

		// Edit second entry
		editor_state.set_content_from_history(entry2.id);
		editor_state.current_content = 'Modified 2';
		const unsaved2_id = editor_state.unsaved_edit_entry_id;

		// Verify both unsaved entries exist
		expect(unsaved1_id).not.toBeNull();
		expect(unsaved2_id).not.toBeNull();
		expect(unsaved1_id).not.toBe(unsaved2_id);

		// Verify both entries in history
		const unsaved1 = history.find_entry_by_id(unsaved1_id!);
		const unsaved2 = history.find_entry_by_id(unsaved2_id!);

		expect(unsaved1).toMatchObject({
			content: 'Modified 1',
			is_unsaved_edit: true,
		});

		expect(unsaved2).toMatchObject({
			content: 'Modified 2',
			is_unsaved_edit: true,
		});
	});

	test('clear_unsaved_edits removes all unsaved entries', () => {
		// Create multiple unsaved edits
		const history = app.get_diskfile_history(TEST_PATH)!;

		// Add one through normal editing
		editor_state.current_content = 'Unsaved 1';

		// Add another directly to history
		history.add_entry('Unsaved 2', {is_unsaved_edit: true});

		// Clear unsaved edits
		editor_state.clear_unsaved_edits();

		// Verify all unsaved entries are gone
		const unsaved_after = history.entries.filter((e) => e.is_unsaved_edit);
		expect(unsaved_after.length).toBe(0);

		// Unsaved edit id should be cleared
		expect(editor_state.unsaved_edit_entry_id).toBeNull();
	});

	test('clear_unsaved_edits updates selection when selected entry is removed', () => {
		// Create an unsaved edit and select it
		editor_state.current_content = 'Unsaved edit';
		const unsaved_id = editor_state.unsaved_edit_entry_id;

		// Verify it's selected
		expect(editor_state.selected_history_entry_id).toBe(unsaved_id);

		// Clear unsaved edits
		editor_state.clear_unsaved_edits();

		// Selection should be updated to a valid entry or null
		expect(editor_state.selected_history_entry_id).not.toBe(unsaved_id);
	});
});

describe('history clearing', () => {
	test('clear_history removes all but most recent entry', () => {
		// Add multiple entries
		const history = app.get_diskfile_history(TEST_PATH)!;
		history.add_entry('Entry 1');
		history.add_entry('Entry 2');
		const newest = history.add_entry('Newest entry');

		// Clear history
		editor_state.clear_history();

		// Only one entry should remain
		expect(history.entries.length).toBe(1);
		expect(history.entries[0]).toMatchObject({
			id: newest.id,
			content: 'Newest entry',
			is_original_state: true,
		});

		// Selection should be updated
		expect(editor_state.selected_history_entry_id).toBe(newest.id);
		expect(editor_state.unsaved_edit_entry_id).toBeNull();
	});

	test('clear_history preserves all unsaved edits', () => {
		// Setup history with both saved and unsaved entries
		const history = app.get_diskfile_history(TEST_PATH)!;

		// Add a saved entry
		history.add_entry('Newest entry');

		// Add two unsaved entries
		const unsaved_entry1 = history.add_entry('Unsaved edit 1', {
			is_unsaved_edit: true,
			label: 'Unsaved 1',
		});

		const unsaved_entry2 = history.add_entry('Unsaved edit 2', {
			is_unsaved_edit: true,
			label: 'Unsaved 2',
		});

		// Clear history
		editor_state.clear_history();

		// Verify the specific unsaved entries still exist
		expect(history.find_entry_by_id(unsaved_entry1.id)).toMatchObject({
			content: 'Unsaved edit 1',
			is_unsaved_edit: true,
			label: 'Unsaved 1',
		});

		expect(history.find_entry_by_id(unsaved_entry2.id)).toMatchObject({
			content: 'Unsaved edit 2',
			is_unsaved_edit: true,
			label: 'Unsaved 2',
		});

		// Verify the newest non-unsaved entry was also preserved
		const newest_after_clear = history.entries.find((entry) => !entry.is_unsaved_edit);
		expect(newest_after_clear).toMatchObject({
			content: 'Newest entry',
			is_original_state: true,
		});

		// Verify the original entry was removed (since it's not the newest saved entry)
		const original_entry = history.entries.find((entry) => entry.content === TEST_CONTENT);
		expect(original_entry).toBeUndefined();
	});
});
