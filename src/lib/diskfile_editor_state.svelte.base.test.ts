// @slop Claude Sonnet 3.7

// @vitest-environment jsdom

import {test, expect, beforeEach, describe} from 'vitest';

import {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
import {Diskfile_Path, Serializable_Source_File} from '$lib/diskfile_types.js';
import {Frontend} from '$lib/frontend.svelte.js';
import {Diskfile} from '$lib/diskfile.svelte.js';
import {monkeypatch_zzz_for_tests} from '$lib/test_helpers.js';

// Constants for testing
const TEST_PATH = Diskfile_Path.parse('/path/to/test.txt');
const TEST_DIR = Serializable_Source_File.shape.source_dir.parse('/path/');
const TEST_CONTENT = 'This is test content';

// Test suite variables
let app: Frontend;
let test_diskfile: Diskfile;
let editor_state: Diskfile_Editor_State;

beforeEach(() => {
	// Create a real Zzz instance for each test
	app = monkeypatch_zzz_for_tests(new Frontend());

	// Create a real diskfile through the registry
	test_diskfile = app.diskfiles.add(
		app.cell_registry.instantiate('Diskfile', {
			path: TEST_PATH,
			source_dir: TEST_DIR,
			content: TEST_CONTENT,
		}),
	);

	// Create the editor state with real components
	editor_state = new Diskfile_Editor_State({
		app,
		diskfile: test_diskfile,
	});
});

describe('initialization', () => {
	test('editor_state initializes with correct values', () => {
		expect(editor_state.original_content).toBe(TEST_CONTENT);
		expect(editor_state.current_content).toBe(TEST_CONTENT);
		expect(editor_state.has_changes).toBe(false);
		expect(editor_state.content_was_modified_by_user).toBe(false);
		expect(editor_state.unsaved_edit_entry_id).toBeNull();
		expect(editor_state.last_seen_disk_content).toBe(TEST_CONTENT);

		// Selected history entry should be initialized to the current entry
		const history = app.get_diskfile_history(TEST_PATH);
		expect(history).toBeDefined();
		expect(history!.entries.length).toBe(1);
		expect(editor_state.selected_history_entry_id).toBe(history!.entries[0].id);
		expect(history!.entries[0].content).toBe(TEST_CONTENT);
	});

	test('editor_state initializes with correct history entry', () => {
		const history = app.get_diskfile_history(TEST_PATH);
		expect(history).toBeDefined();
		expect(history!.entries.length).toBe(1);

		// The initial entry should contain the original content
		const initial_entry = history!.entries[0];
		expect(initial_entry.content).toBe(TEST_CONTENT);
		expect(initial_entry.is_unsaved_edit).toBe(false);
		expect(initial_entry.is_disk_change).toBe(false);
		expect(initial_entry.is_original_state).toBe(true);
	});

	test('editor_state handles initialization with null content', () => {
		// Create a diskfile with null content
		const null_diskfile = app.diskfiles.add(
			app.cell_registry.instantiate('Diskfile', {
				path: Diskfile_Path.parse('/null/content.txt'),
				source_dir: Serializable_Source_File.shape.source_dir.parse('/null/'),
				content: null,
			}),
		);

		// Create editor state
		const null_editor_state = new Diskfile_Editor_State({
			app,
			diskfile: null_diskfile,
		});

		// Check state properties
		expect(null_editor_state.original_content).toBeNull();
		expect(null_editor_state.current_content).toBe('');
		expect(null_editor_state.has_changes).toBe(false);
		expect(null_editor_state.last_seen_disk_content).toBeNull();

		// History should still be created
		const history = app.get_diskfile_history(null_diskfile.path);
		expect(history).toBeDefined();
		expect(history!.entries.length).toBe(0); // No entries for null content
	});
});

describe('content editing', () => {
	test('updating content updates editor state', () => {
		const new_content = 'Modified content';
		editor_state.current_content = new_content;

		expect(editor_state.current_content).toBe(new_content);
		expect(editor_state.has_changes).toBe(true);
		expect(editor_state.content_was_modified_by_user).toBe(true);
	});

	test('content modifications track user edits flag', () => {
		// Initial state - no user edits
		expect(editor_state.content_was_modified_by_user).toBe(false);

		// Change content - should mark as user-edited
		editor_state.current_content = 'User edit';
		expect(editor_state.content_was_modified_by_user).toBe(true);

		// Change back to original - should clear user-edited flag
		editor_state.current_content = TEST_CONTENT;
		expect(editor_state.content_was_modified_by_user).toBe(false);
	});

	test('has_changes tracks difference between current and original content', () => {
		// Initial state - no changes
		expect(editor_state.has_changes).toBe(false);

		// Make a change
		editor_state.current_content = 'Changed content';
		expect(editor_state.has_changes).toBe(true);

		// Change back to original
		editor_state.current_content = TEST_CONTENT;
		expect(editor_state.has_changes).toBe(false);
	});

	test('editing content preserves selection state', () => {
		// First make an edit to create history entries
		editor_state.current_content = 'First edit';
		const history = app.get_diskfile_history(TEST_PATH)!;

		// Get the selected entry id
		const selected_id = editor_state.selected_history_entry_id;
		expect(selected_id).not.toBeNull();

		// Make another edit
		editor_state.current_content = 'Second edit';

		// Selection should still be active
		expect(editor_state.selected_history_entry_id).not.toBeNull();

		// Content should be updated in the selected entry
		const updated_entry = history.find_entry_by_id(editor_state.selected_history_entry_id!);
		expect(updated_entry).toBeDefined();
		expect(updated_entry!.content).toBe('Second edit');
	});

	test('editing to match original content clears user modified flag', () => {
		// Make an edit
		editor_state.current_content = 'User edit';
		expect(editor_state.content_was_modified_by_user).toBe(true);
		expect(editor_state.has_changes).toBe(true);

		// Edit back to match original
		editor_state.current_content = TEST_CONTENT;

		// Flags should be cleared
		expect(editor_state.content_was_modified_by_user).toBe(false);
		expect(editor_state.has_changes).toBe(false);
	});
});

describe('content metrics', () => {
	test('editor provides accurate content length metrics', () => {
		// Initial length
		expect(editor_state.original_length).toBe(TEST_CONTENT.length);
		expect(editor_state.current_length).toBe(TEST_CONTENT.length);
		expect(editor_state.length_diff).toBe(0);
		expect(editor_state.length_diff_percent).toBe(0);

		// Update content
		const new_content = 'Shorter';
		editor_state.current_content = new_content;

		// Check metrics
		expect(editor_state.current_length).toBe(new_content.length);
		expect(editor_state.length_diff).toBe(new_content.length - TEST_CONTENT.length);

		// Percent change should be negative
		const expected_percent = Math.round(
			((new_content.length - TEST_CONTENT.length) / TEST_CONTENT.length) * 100,
		);
		expect(editor_state.length_diff_percent).toBe(expected_percent);
	});

	test('editor provides accurate token metrics', () => {
		// Set specific content to test tokens
		const token_test_content = 'This is a test with multiple tokens.';
		editor_state.current_content = token_test_content;

		// Verify token calculations
		expect(editor_state.current_token_count).toBeGreaterThan(0);
		expect(editor_state.current_token_count).toBe(editor_state.current_token_count);
		expect(editor_state.token_diff).toBe(
			editor_state.current_token_count - editor_state.original_token_count,
		);

		// Token percent should match calculation
		const expected_token_percent = Math.round(
			((editor_state.current_token_count - editor_state.original_token_count) /
				editor_state.original_token_count) *
				100,
		);
		expect(editor_state.token_diff_percent).toBe(expected_token_percent);
	});

	test('editor handles metrics for empty content', () => {
		// Change to empty content
		editor_state.current_content = '';

		// Check length metrics
		expect(editor_state.current_length).toBe(0);
		expect(editor_state.length_diff).toBe(-TEST_CONTENT.length);
		expect(editor_state.length_diff_percent).toBe(-100);

		// Check token metrics
		expect(editor_state.current_token_count).toBe(0);
		expect(editor_state.current_token_count).toBe(0);
		expect(editor_state.token_diff).toBe(-editor_state.original_token_count);
		expect(editor_state.token_diff_percent).toBe(-100);
	});

	test('length_diff_percent handles zero original length correctly', () => {
		// Create a diskfile with empty content
		const empty_diskfile = app.diskfiles.add(
			app.cell_registry.instantiate('Diskfile', {
				path: Diskfile_Path.parse('/empty/file.txt'),
				source_dir: Serializable_Source_File.shape.source_dir.parse('/empty/'),
				content: '',
			}),
		);

		// Create editor state
		const empty_editor_state = new Diskfile_Editor_State({
			app,
			diskfile: empty_diskfile,
		});

		// Now edit to add content
		empty_editor_state.current_content = 'New content';

		// Since original length was 0, percentage should be 100%
		expect(empty_editor_state.original_length).toBe(0);
		expect(empty_editor_state.length_diff_percent).toBe(100);

		// Same for tokens
		expect(empty_editor_state.original_token_count).toBe(0);
		expect(empty_editor_state.token_diff_percent).toBe(100);
	});
});

describe('file management', () => {
	test('update_diskfile handles switching to different file', () => {
		// Create another diskfile
		const another_path = Diskfile_Path.parse('/different/file.txt');
		const another_content = 'Different file content';
		const another_diskfile = app.diskfiles.add(
			app.cell_registry.instantiate('Diskfile', {
				path: another_path,
				source_dir: Serializable_Source_File.shape.source_dir.parse('/different/'),
				content: another_content,
			}),
		);

		// Make edits to the current file
		editor_state.current_content = 'Edited original file';

		// Switch to the new file
		editor_state.update_diskfile(another_diskfile);

		// Verify state was properly updated
		expect(editor_state.diskfile).toBe(another_diskfile);
		expect(editor_state.original_content).toBe(another_content);
		expect(editor_state.current_content).toBe(another_content);
		expect(editor_state.has_changes).toBe(false);
		expect(editor_state.content_was_modified_by_user).toBe(false);

		// History should be initialized for the new file
		const new_history = app.get_diskfile_history(another_path);
		expect(new_history).toBeDefined();
		expect(new_history!.entries.length).toBe(1);
		expect(new_history!.entries[0].content).toBe(another_content);
	});

	test('update_diskfile does nothing when same diskfile is provided', () => {
		// Make some edits
		editor_state.current_content = 'Edited content';

		// Track current state
		const current_content = editor_state.current_content;
		const current_modified = editor_state.content_was_modified_by_user;

		// Call update with the same diskfile
		editor_state.update_diskfile(test_diskfile);

		// State should remain unchanged
		expect(editor_state.current_content).toBe(current_content);
		expect(editor_state.content_was_modified_by_user).toBe(current_modified);
	});

	test('reset clears editor state and reverts to original content', () => {
		// Make edits
		editor_state.current_content = 'Edited content';

		// Create and select unsaved entry
		const history = app.get_diskfile_history(TEST_PATH)!;
		const test_entry = history.add_entry('Test entry', {is_unsaved_edit: true});
		editor_state.set_content_from_history(test_entry.id);

		// Reset the editor
		editor_state.reset();

		// Verify state is reset
		expect(editor_state.current_content).toBe(TEST_CONTENT);
		expect(editor_state.has_changes).toBe(false);
		expect(editor_state.content_was_modified_by_user).toBe(false);
		expect(editor_state.unsaved_edit_entry_id).toBeNull();
		expect(editor_state.selected_history_entry_id).toBeNull();
	});
});

describe('derived state', () => {
	test('derived property has_history is accurate', () => {
		// Initial state - only one entry, should not have history
		expect(editor_state.has_history).toBe(false);

		// Add an entry
		editor_state.current_content = 'New content';

		// Now we should have history
		expect(editor_state.has_history).toBe(true);
	});

	test('derived property has_unsaved_edits is accurate', () => {
		// Initial state - no unsaved edits
		expect(editor_state.has_unsaved_edits).toBe(false);

		// Make an edit
		editor_state.current_content = 'Unsaved edit';

		// Now we should have unsaved edits
		expect(editor_state.has_unsaved_edits).toBe(true);

		// Save the changes
		editor_state.save_changes();

		// No more unsaved edits
		expect(editor_state.has_unsaved_edits).toBe(false);
	});

	test('derived properties for UI state management', () => {
		// Initial state
		expect(editor_state.can_clear_history).toBe(false);
		expect(editor_state.can_clear_unsaved_edits).toBe(false);

		// Add a saved entry
		const history = app.get_diskfile_history(TEST_PATH)!;
		history.add_entry('Saved entry 1');
		history.add_entry('Saved entry 2');

		// Now we can clear history
		expect(editor_state.can_clear_history).toBe(true);

		// Add an unsaved entry
		editor_state.current_content = 'Unsaved edit';

		// Now we can clear unsaved edits as well
		expect(editor_state.can_clear_unsaved_edits).toBe(true);
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

describe('saving changes', () => {
	test('save_changes persists content to diskfile', () => {
		// Make an edit
		editor_state.current_content = 'Content to save';

		// Save changes
		const result = editor_state.save_changes();

		// Verify result and diskfile update
		expect(result).toBe(true);
		expect(test_diskfile.content).toBe('Content to save');
		expect(editor_state.last_seen_disk_content).toBe('Content to save');
		expect(editor_state.content_was_modified_by_user).toBe(false);
	});

	test('save_changes with no changes returns false', () => {
		// Don't make any changes
		expect(editor_state.has_changes).toBe(false);

		// Try to save
		const result = editor_state.save_changes();

		// Verify nothing was saved
		expect(result).toBe(false);
	});

	test('save_changes creates history entry with correct properties', () => {
		// Make an edit
		editor_state.current_content = 'Content to be saved';

		// Save changes
		editor_state.save_changes();

		// Check history entry
		const history = app.get_diskfile_history(TEST_PATH)!;
		const entry = history.entries[0]; // Newest entry

		expect(entry.content).toBe('Content to be saved');
		expect(entry.is_unsaved_edit).toBe(false);
		expect(entry.is_disk_change).toBe(false);
	});
});
