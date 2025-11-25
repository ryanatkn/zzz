// @slop Claude Sonnet 3.7

// @vitest-environment jsdom

import {test, expect, beforeEach, describe} from 'vitest';

import {DiskfileEditorState} from '$lib/diskfile_editor_state.svelte.js';
import {DiskfilePath, SerializableDisknode} from '$lib/diskfile_types.js';
import {Frontend} from '$lib/frontend.svelte.js';
import {Diskfile} from '$lib/diskfile.svelte.js';
import {monkeypatch_zzz_for_tests} from '$lib/test_helpers.js';

// Constants for testing
const TEST_PATH = DiskfilePath.parse('/path/to/test.txt');
const TEST_DIR = SerializableDisknode.shape.source_dir.parse('/path/');
const TEST_CONTENT = 'This is test content';

// Test suite variables
let app: Frontend;
let test_diskfile: Diskfile;
let editor_state: DiskfileEditorState;

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
	editor_state = new DiskfileEditorState({
		app,
		diskfile: test_diskfile,
	});
});

describe('disk change detection', () => {
	test('identifies when disk content changes', () => {
		// Initial state - no disk content tracking issues
		expect(editor_state.last_seen_disk_content).toBe(TEST_CONTENT);

		// Simulate a change on disk
		const new_disk_content = 'Content changed on disk';
		test_diskfile.content = new_disk_content;

		// Check for disk changes
		editor_state.check_disk_changes();

		// Since there are no user edits, content should be auto-updated
		expect(editor_state.current_content).toBe(new_disk_content);
		expect(editor_state.last_seen_disk_content).toBe(new_disk_content);
	});

	test('with no user edits automatically updates content and selection', () => {
		// Simulate change on disk
		const disk_content = 'Changed content on disk';
		test_diskfile.content = disk_content;

		// Check for disk changes
		editor_state.check_disk_changes();

		// Content should be auto-updated
		expect(editor_state.current_content).toBe(disk_content);
		expect(editor_state.last_seen_disk_content).toBe(disk_content);

		// History should have a new entry with disk change flag
		const history = app.get_diskfile_history(TEST_PATH)!;
		const disk_entry = history.entries.find(
			(entry) => entry.is_disk_change && entry.content === disk_content,
		);

		expect(disk_entry).toMatchObject({
			content: disk_content,
			is_disk_change: true,
		});

		// Selection should point to the new disk change entry
		expect(editor_state.selected_history_entry_id).toBe(disk_entry!.id);
	});

	test('ignores null content states', () => {
		// Set up null content states
		test_diskfile.content = null;
		editor_state.last_seen_disk_content = null;

		// Check for disk changes
		editor_state.check_disk_changes();

		// Nothing should happen, no errors
		expect(editor_state.last_seen_disk_content).toBeNull();
	});

	test('does nothing if disk content matches last seen', () => {
		// Set last seen content
		editor_state.last_seen_disk_content = 'Last seen content';
		test_diskfile.content = 'Last seen content';

		// Check for disk changes
		editor_state.check_disk_changes();

		// Last seen should remain unchanged
		expect(editor_state.last_seen_disk_content).toBe('Last seen content');
	});

	test('handles first-time initialization correctly', () => {
		// Create a new diskfile with uninitialized last_seen_disk_content
		const new_diskfile = app.diskfiles.add({
			path: DiskfilePath.parse('/new/file.txt'),
			source_dir: SerializableDisknode.shape.source_dir.parse('/new/'),
			content: 'Initial content',
		});

		const new_editor_state = new DiskfileEditorState({
			app,
			diskfile: new_diskfile,
		});

		// Artificially set last_seen_disk_content to null to simulate first check
		new_editor_state.last_seen_disk_content = null;

		// Check for disk changes
		new_editor_state.check_disk_changes();

		// last_seen_disk_content should be initialized
		expect(new_editor_state.last_seen_disk_content).toBe('Initial content');
		expect(new_editor_state.current_content).toBe('Initial content');
	});

	test('with user edits adds disk change to history but preserves user content', () => {
		// First make a user edit
		editor_state.current_content = 'User edited content';
		expect(editor_state.content_was_modified_by_user).toBe(true);

		// Simulate disk change
		test_diskfile.content = 'Changed on disk';
		editor_state.check_disk_changes();

		// User content should be preserved
		expect(editor_state.current_content).toBe('User edited content');

		// Last seen content should be updated
		expect(editor_state.last_seen_disk_content).toBe('Changed on disk');

		// Find the disk change entry
		const history = app.get_diskfile_history(TEST_PATH)!;
		const disk_entry = history.entries.find(
			(entry) => entry.is_disk_change && entry.content === 'Changed on disk',
		);

		expect(disk_entry).toMatchObject({
			content: 'Changed on disk',
			is_disk_change: true,
		});

		// Selection should not automatically change to disk entry
		expect(editor_state.selected_history_entry_id).not.toBe(disk_entry!.id);
	});

	test('skips adding disk change if content matches existing entries', () => {
		// First make a disk change
		test_diskfile.content = 'First disk change';
		editor_state.check_disk_changes();

		const history = app.get_diskfile_history(TEST_PATH)!;
		const count_after_first = history.entries.length;

		// Now make the same disk change again
		editor_state.check_disk_changes();

		// No new entry should be added
		expect(history.entries.length).toBe(count_after_first);
	});

	test('marks existing entry as disk change when content matches', () => {
		// Add an entry to history that isn't initially marked as a disk change
		const history = app.get_diskfile_history(TEST_PATH)!;
		const entry = history.add_entry('New content on disk', {
			is_disk_change: false,
			is_unsaved_edit: true, // Initially mark as unsaved
		});

		// Verify the entry isn't marked as a disk change yet
		expect(entry.is_disk_change).toBe(false);
		expect(entry.is_unsaved_edit).toBe(true);

		// Make a disk change that matches the existing entry's content
		test_diskfile.content = 'New content on disk';
		editor_state.check_disk_changes();

		// The existing entry should now be marked as a disk change and not an unsaved edit
		expect(history.entries[0]!.is_disk_change).toBe(true);
		expect(history.entries[0]!.is_unsaved_edit).toBe(false);

		// No new entry should be created
		expect(history.entries.length).toBe(2); // Original + our added entry
	});
});

describe('file history management', () => {
	test('creates history entries for disk changes', () => {
		// Initial state
		const history = app.get_diskfile_history(TEST_PATH)!;

		// Make a sequence of disk changes
		test_diskfile.content = 'First disk change';
		editor_state.check_disk_changes();

		test_diskfile.content = 'Second disk change';
		editor_state.check_disk_changes();

		// Verify disk change entries exist with correct content
		const firstEntry = history.entries.find(
			(e) => e.content === 'First disk change' && e.is_disk_change,
		);

		const secondEntry = history.entries.find(
			(e) => e.content === 'Second disk change' && e.is_disk_change,
		);

		expect(firstEntry).toMatchObject({
			content: 'First disk change',
			is_disk_change: true,
		});

		expect(secondEntry).toMatchObject({
			content: 'Second disk change',
			is_disk_change: true,
		});
	});

	test('preserves selection when user has made edits', () => {
		// Make a user edit
		editor_state.current_content = 'User edit';
		const selected_id = editor_state.selected_history_entry_id;

		// Simulate disk change
		test_diskfile.content = 'Disk change';
		editor_state.check_disk_changes();

		// Selection should remain on user's edit
		expect(editor_state.selected_history_entry_id).toBe(selected_id);
	});

	test('with user selection of older history maintains that selection during disk change', () => {
		// Add entries to history
		const history = app.get_diskfile_history(TEST_PATH)!;
		const older_entry = history.add_entry('Older entry');

		// Select the older entry
		editor_state.set_content_from_history(older_entry.id);
		expect(editor_state.selected_history_entry_id).toBe(older_entry.id);

		// Simulate disk change
		test_diskfile.content = 'New disk content';
		editor_state.check_disk_changes();

		// Selection should remain on the older entry
		expect(editor_state.selected_history_entry_id).toBe(older_entry.id);
	});
});

describe('save changes behavior', () => {
	test('save_changes persists content and updates tracking', async () => {
		// Make user edits
		editor_state.current_content = 'User edit to save';

		// Save changes
		await editor_state.save_changes();

		// Content should be saved to disk
		expect(test_diskfile.content).toBe('User edit to save');

		// Last seen disk content should be updated
		expect(editor_state.last_seen_disk_content).toBe('User edit to save');

		// User modified flag should be cleared
		expect(editor_state.content_was_modified_by_user).toBe(false);
	});

	test('saving during disk changes preserves selected content', async () => {
		// Make user edit
		editor_state.current_content = 'User edit';

		// Simulate disk change
		test_diskfile.content = 'Disk change';
		editor_state.check_disk_changes();

		// Save user changes (should overwrite disk change)
		await editor_state.save_changes();

		// Disk should have user content
		expect(test_diskfile.content).toBe('User edit');

		// Last seen content should be updated
		expect(editor_state.last_seen_disk_content).toBe('User edit');
	});
});

describe('edge cases', () => {
	test('handles empty string disk content correctly', () => {
		// Simulate disk change to empty string
		test_diskfile.content = '';
		editor_state.check_disk_changes();

		// With no user edits, content should be updated to empty
		expect(editor_state.current_content).toBe('');
		expect(editor_state.last_seen_disk_content).toBe('');

		// History should include empty content entry
		const history = app.get_diskfile_history(TEST_PATH)!;
		const empty_entry = history.entries.find((e) => e.content === '' && e.is_disk_change);

		expect(empty_entry).toMatchObject({
			content: '',
			is_disk_change: true,
		});
	});

	test('handles disk changes when history is empty', () => {
		// Create a new diskfile with a custom path
		const empty_history_path = DiskfilePath.parse('/empty/history.txt');
		const empty_history_diskfile = app.diskfiles.add({
			path: empty_history_path,
			source_dir: SerializableDisknode.shape.source_dir.parse('/empty/'),
			content: 'Initial',
		});

		// Create editor state but clear the history manually
		const empty_history_editor = new DiskfileEditorState({
			app,
			diskfile: empty_history_diskfile,
		});

		// Manually clear history entries
		const history = app.get_diskfile_history(empty_history_path)!;
		history.entries = [];

		// Simulate disk change
		empty_history_diskfile.content = 'Disk changed';
		empty_history_editor.check_disk_changes();

		// Should handle gracefully without errors
		expect(empty_history_editor.current_content).toBe('Disk changed');

		// The implementation should create an entry with the disk_change flag
		expect(history.entries[0]!).toMatchObject({
			content: 'Disk changed',
			is_disk_change: true,
		});
	});

	test('changing diskfile to null content is handled properly', () => {
		// First make an edit
		editor_state.current_content = 'User edit';

		// Change content to null
		test_diskfile.content = null;

		// Check for changes
		editor_state.check_disk_changes();

		// Should not crash and maintain same state
		expect(editor_state.current_content).toBe('User edit');
	});

	test('editing to match disk content is handled properly', () => {
		// Set up an initial disk change without selecting it
		test_diskfile.content = 'Disk content';
		editor_state.check_disk_changes();

		// Make user edit to match disk content
		editor_state.current_content = 'Disk content';

		// User modified state should be false since it matches disk content
		expect(editor_state.content_was_modified_by_user).toBe(false);
	});
});
