// @vitest-environment jsdom

import {test, expect, vi} from 'vitest';

import {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
import {Diskfile_Path} from '$lib/diskfile_types.js';
import {Uuid} from '$lib/zod_helpers.js';
import type {History_Entry} from '$lib/diskfile_history.svelte.js';

// Create a mock diskfile
const create_mock_diskfile = (content: string | null = 'initial content') => {
	class Mock_Diskfile {
		id = $state(Uuid.parse(undefined));
		path = $state(Diskfile_Path.parse('/path/to/file.txt'));
		content = $state(content);
		created = $state(new Date().toISOString());
		updated = $state(new Date().toISOString());
		created_formatted_date = $state('mock date');
		updated_formatted_date = $state('mock date');
	}

	return new Mock_Diskfile();
};

// Mock timestamp for consistent testing
const MOCK_TIMESTAMP = 1234567890;

// Create a mock diskfile history
const create_mock_history = () => {
	// Define entries with proper type
	const entries: Array<History_Entry> = $state([]);

	const history = {
		entries,
		add_entry: vi.fn((content: string, options: any = {}) => {
			const entry: History_Entry = {
				id: Uuid.parse(undefined),
				created: options.created ?? MOCK_TIMESTAMP,
				content,
				is_disk_change: options.is_disk_change ?? false,
			};

			if (options.label) {
				entry.label = options.label;
			}

			entries.push(entry);
			return entry;
		}),
		get_content: vi.fn((id: Uuid) => {
			const entry = entries.find((e) => e.id === id);
			return entry ? entry.content : null;
		}),
		find_entry_by_id: vi.fn((id: Uuid) => {
			return entries.find((e) => e.id === id);
		}),
		clear_except_current: vi.fn(() => {
			if (entries.length > 0) {
				const lastEntry = entries[entries.length - 1];
				entries.length = 0;
				entries.push(lastEntry);
			}
		}),
	};

	return history;
};

// Create a mock zzz object with minimal functionality needed for tests
const create_mock_zzz = () => {
	const mock_history = create_mock_history();

	return {
		diskfiles: {
			update: vi.fn(),
			delete: vi.fn(),
			to_relative_path: vi.fn((path) => path),
		},
		// Modified to follow the new pattern with separate lookup and creation functions
		maybe_get_diskfile_history: vi.fn(() => mock_history),
		create_diskfile_history: vi.fn(() => mock_history),
		time: {
			now: vi.fn(() => MOCK_TIMESTAMP),
		},
	};
};

test('Diskfile_Editor_State - basic initialization', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile();

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Check initial state
	expect(editor_state.diskfile).toEqual(mock_diskfile);
	expect(editor_state.original_content).toBe(mock_diskfile.content);
	expect(editor_state.updated_content).toBe(mock_diskfile.content);
	expect(editor_state.has_changes).toBe(false);
	expect(editor_state.content_was_modified_by_user).toBe(false);
	expect(editor_state.disk_changed).toBe(false);

	// Check that #ensure_history was called through maybe_get_diskfile_history
	expect(mock_zzz.maybe_get_diskfile_history).toHaveBeenCalledWith(mock_diskfile.path);

	// Check that add_entry was called with initial content
	const mock_history = mock_zzz.maybe_get_diskfile_history();
	expect(mock_history.add_entry).toHaveBeenCalledWith('initial content');
});

test('Diskfile_Editor_State - updated_content getter/setter', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile();

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Initial state
	expect(editor_state.updated_content).toBe(mock_diskfile.content);
	expect(editor_state.content_was_modified_by_user).toBe(false);

	// Update using setter
	editor_state.updated_content = 'changed content';

	// Check if state updated correctly
	expect(editor_state.updated_content).toBe('changed content');
	expect(editor_state.content_was_modified_by_user).toBe(true);
	expect(editor_state.has_changes).toBe(true);
});

test('Diskfile_Editor_State - save_changes', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile();

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Change content
	editor_state.updated_content = 'modified content';

	// Save changes
	const result = editor_state.save_changes();

	// Verify results
	expect(result).toBe(true);
	expect(mock_zzz.diskfiles.update).toHaveBeenCalledWith(mock_diskfile.path, 'modified content');
	expect(editor_state.history?.add_entry).toHaveBeenCalledWith('modified content');
	expect(editor_state.content_was_modified_by_user).toBe(false);
});

test('Diskfile_Editor_State - save_changes with no changes returns false', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile();

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// No changes made
	const result = editor_state.save_changes();

	// Verify no action taken
	expect(result).toBe(false);
	expect(mock_zzz.diskfiles.update).not.toHaveBeenCalled();
});

test('Diskfile_Editor_State - discard_changes', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile();

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Make changes
	editor_state.updated_content = 'changed content';
	expect(editor_state.has_changes).toBe(true);

	// Discard changes
	editor_state.discard_changes('');

	// Verify state is reset
	expect(editor_state.updated_content).toBe(mock_diskfile.content);
	expect(editor_state.has_changes).toBe(false);
	expect(editor_state.content_was_modified_by_user).toBe(false);
	expect(editor_state.discarded_content).toBe('changed content');
});

test('Diskfile_Editor_State - discard_changes with restore value', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile();

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Make changes
	editor_state.updated_content = 'changed content';

	// Discard changes
	editor_state.discard_changes('');

	// Restore discarded changes
	editor_state.discard_changes('changed content');

	// Verify state
	expect(editor_state.updated_content).toBe('changed content');
	expect(editor_state.has_changes).toBe(true);
	expect(editor_state.content_was_modified_by_user).toBe(true);
	expect(editor_state.discarded_content).toBe(null);
});

test('Diskfile_Editor_State - update_diskfile', () => {
	const mock_zzz = create_mock_zzz();
	const initial_diskfile = create_mock_diskfile('initial content');
	const new_diskfile = create_mock_diskfile('new content');

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: initial_diskfile as any,
	});

	// Make changes to original diskfile
	editor_state.updated_content = 'user changes';

	// Update to new diskfile
	editor_state.update_diskfile(new_diskfile as any);

	// Verify state is reset with new diskfile
	expect(editor_state.diskfile).toEqual(new_diskfile);
	expect(editor_state.original_content).toBe('new content');
	expect(editor_state.updated_content).toBe('new content');
	expect(editor_state.has_changes).toBe(false);
	expect(editor_state.content_was_modified_by_user).toBe(false);
});

test('Diskfile_Editor_State - check_disk_changes with no user edits', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile('initial content');

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Set up initial state
	expect(editor_state.last_seen_disk_content).toBe('initial content');

	// Simulate file change on disk
	mock_diskfile.content = 'updated on disk';

	// Check for changes
	editor_state.check_disk_changes();

	// Verify editor auto-updated
	expect(editor_state.updated_content).toBe('updated on disk');
	expect(editor_state.last_seen_disk_content).toBe('updated on disk');
	expect(editor_state.disk_changed).toBe(false);
	expect(editor_state.content_history.length).toBe(2);
});

test('Diskfile_Editor_State - check_disk_changes with user edits', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile('initial content');

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Make user edits
	editor_state.updated_content = 'user edits';

	// Simulate file change on disk
	mock_diskfile.content = 'updated on disk';

	// Check for changes
	editor_state.check_disk_changes();

	// Verify notification state
	expect(editor_state.updated_content).toBe('user edits');
	expect(editor_state.disk_changed).toBe(true);
	expect(editor_state.disk_content).toBe('updated on disk');
});

test('Diskfile_Editor_State - accept_disk_changes', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile('initial content');

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Make user edits
	editor_state.updated_content = 'user edits';

	// Simulate file change on disk
	mock_diskfile.content = 'updated on disk';
	editor_state.check_disk_changes();

	// Verify notification state
	expect(editor_state.disk_changed).toBe(true);
	expect(editor_state.updated_content).toBe('user edits');

	// Accept disk changes
	editor_state.accept_disk_changes();

	// Verify state updated
	expect(editor_state.updated_content).toBe('updated on disk');
	expect(editor_state.disk_changed).toBe(false);
	expect(editor_state.disk_content).toBe(null);
	expect(editor_state.content_was_modified_by_user).toBe(false);
	expect(editor_state.content_history.length).toBe(3); // Initial + user edit + disk content
});

test('Diskfile_Editor_State - reject_disk_changes', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile('initial content');

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Make user edits
	editor_state.updated_content = 'user edits';

	// Simulate file change on disk
	mock_diskfile.content = 'updated on disk';
	editor_state.check_disk_changes();

	// Reject disk changes
	editor_state.reject_disk_changes();

	// Verify state updated but content preserved
	expect(editor_state.updated_content).toBe('user edits');
	expect(editor_state.disk_changed).toBe(false);
	expect(editor_state.disk_content).toBe(null);
	expect(editor_state.last_seen_disk_content).toBe('updated on disk');
	expect(editor_state.content_was_modified_by_user).toBe(true);
});

test('Diskfile_Editor_State - calculated metrics are updated when content changes', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile('initial content');

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Check initial metrics
	expect(editor_state.original_length).toBe(15); // 'initial content'
	expect(editor_state.updated_length).toBe(15);
	expect(editor_state.length_diff).toBe(0);
	expect(editor_state.length_diff_percent).toBe(0);

	// Update content and check metrics
	editor_state.updated_content = 'updated longer content with more tokens';

	// Length metrics
	expect(editor_state.updated_length).toBe(39);
	expect(editor_state.length_diff).toBe(24);
	expect(editor_state.length_diff_percent).toBe(160);

	// Token metrics should also be updated
	expect(editor_state.updated_token_count).toBeGreaterThan(editor_state.original_token_count);
	expect(editor_state.token_diff).toBe(
		editor_state.updated_token_count - editor_state.original_token_count,
	);
});

test('Diskfile_Editor_State - set_content_from_history', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile('initial content');

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	const mock_history = mock_zzz.maybe_get_diskfile_history();

	// Create entry IDs
	const entry1_id = Uuid.parse(undefined);
	const entry2_id = Uuid.parse(undefined);

	// Set up mock to return specific content
	mock_history.get_content.mockImplementation((id) => {
		if (id === entry1_id) return 'first edit';
		if (id === entry2_id) return 'second edit';
		return null;
	});

	// Set to point in history
	editor_state.set_content_from_history(entry1_id);

	// Verify state
	expect(editor_state.updated_content).toBe('first edit');
	expect(editor_state.content_was_modified_by_user).toBe(true);
	expect(mock_history.get_content).toHaveBeenCalledWith(entry1_id);
});

test('Diskfile_Editor_State - handles null content gracefully', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile(null);

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Check that null content is handled
	expect(editor_state.original_content).toBe(null);
	expect(editor_state.updated_content).toBe('');
	expect(editor_state.original_length).toBe(0);
	expect(editor_state.updated_length).toBe(0);
	expect(editor_state.length_diff).toBe(0);
	expect(editor_state.original_tokens).toEqual([]);
});

test('Diskfile_Editor_State - reject_disk_changes adds ignored changes to history', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile('initial content');

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Make user edits
	editor_state.updated_content = 'user edits';

	// Get initial history length
	const initial_history_length = editor_state.content_history.length;

	// Simulate file change on disk
	mock_diskfile.content = 'updated on disk';
	editor_state.check_disk_changes();

	// Reject disk changes
	editor_state.reject_disk_changes();

	// Verify history contains the ignored change
	expect(editor_state.content_history.length).toBe(initial_history_length + 1);

	// Get the latest history entry
	const latest_entry = editor_state.content_history[editor_state.content_history.length - 1];

	// Check that it contains both the marker and the content
	expect(latest_entry.content).toBe('updated on disk');

	// Verify the rest of the state is as expected
	expect(editor_state.updated_content).toBe('user edits');
	expect(editor_state.disk_changed).toBe(false);
	expect(editor_state.disk_content).toBe(null);
});

test('Diskfile_Editor_State - accept_disk_changes uses time from zzz', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile('initial content');

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Make user edits
	editor_state.updated_content = 'user edits';

	// Simulate file change on disk
	mock_diskfile.content = 'updated on disk';
	editor_state.check_disk_changes();

	// Clear previous mock calls
	mock_zzz.time.now.mockClear();
	const mock_history = mock_zzz.maybe_get_diskfile_history();
	mock_history.add_entry.mockClear();

	// Accept disk changes
	editor_state.accept_disk_changes();

	// Remove expectation that mock_zzz.time.now was called because we now use Date.now()
	// Instead, assert that add_entry was called with numeric timestamps:
	expect(mock_history.add_entry).toHaveBeenCalledWith('user edits', {
		created: expect.any(Number),
	});
	expect(mock_history.add_entry).toHaveBeenCalledWith('updated on disk', {
		created: expect.any(Number),
		is_disk_change: true,
		label: 'Accepted disk change',
	});
});

test('Diskfile_Editor_State - reject_disk_changes uses time from zzz', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile('initial content');

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Make user edits
	editor_state.updated_content = 'user edits';

	// Simulate file change on disk
	mock_diskfile.content = 'updated on disk';
	editor_state.check_disk_changes();

	// Clear previous mock calls
	const mock_history = mock_zzz.maybe_get_diskfile_history();
	mock_history.add_entry.mockClear();

	// Reject disk changes
	editor_state.reject_disk_changes();

	// Now check that add_entry got a numeric timestamp
	expect(mock_history.add_entry).toHaveBeenCalledWith('updated on disk', {
		created: expect.any(Number),
		is_disk_change: true,
		label: 'Ignored disk change',
	});
});

test('Diskfile_Editor_State - check_disk_changes uses time from zzz for auto-update', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile('initial content');

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Set up initial state
	expect(editor_state.last_seen_disk_content).toBe('initial content');

	// Simulate file change on disk
	mock_diskfile.content = 'updated on disk';

	// Check for changes
	editor_state.check_disk_changes();

	// Verify editor auto-updated and used the consistent timestamp
	expect(editor_state.updated_content).toBe('updated on disk');
	expect(editor_state.last_seen_disk_content).toBe('updated on disk');
	expect(editor_state.disk_changed).toBe(false);

	expect(editor_state.history?.add_entry).toHaveBeenCalledWith('updated on disk', {
		is_disk_change: true,
		label: 'Disk change',
	});
});

test('Diskfile_Editor_State - clear_history delegates to history object', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile();

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Add some history entries
	editor_state.updated_content = 'first edit';
	editor_state.save_changes();

	editor_state.updated_content = 'second edit';
	editor_state.save_changes();

	// Clear history
	editor_state.clear_history();

	// Verify history was cleared using the history object
	expect(editor_state.history?.clear_except_current).toHaveBeenCalled();
});

test('Diskfile_Editor_State - set_content_from_history uses history object', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile();
	const mock_history = mock_zzz.maybe_get_diskfile_history();

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Create a test UUID
	const entry_id = Uuid.parse(undefined);

	// Setup mock to return content for a specific ID
	mock_history.get_content.mockImplementation((id) => {
		if (id === entry_id) return 'historical content';
		return null;
	});

	// Set content from history
	editor_state.set_content_from_history(entry_id);

	// Verify history object was used to retrieve content
	expect(editor_state.history?.get_content).toHaveBeenCalledWith(entry_id);
	expect(editor_state.updated_content).toBe('historical content');
});

test('Diskfile_Editor_State - update_diskfile gets history for new file', () => {
	const mock_zzz = create_mock_zzz();
	const initial_diskfile = create_mock_diskfile('initial content');
	const new_diskfile = create_mock_diskfile('new content');

	// Configure new_diskfile with a different path
	new_diskfile.path = Diskfile_Path.parse('/path/to/different.txt');

	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: initial_diskfile as any,
	});

	// Reset mock calls to start fresh
	mock_zzz.maybe_get_diskfile_history.mockClear();

	// Update to new diskfile
	editor_state.update_diskfile(new_diskfile as any);

	// Force the derived property to be evaluated by accessing it
	editor_state.history;

	// Verify that maybe_get_diskfile_history was called with the new path
	expect(mock_zzz.maybe_get_diskfile_history).toHaveBeenCalledWith(new_diskfile.path);
});

test('Diskfile_Editor_State - creates history when needed', () => {
	const mock_zzz = create_mock_zzz();
	const mock_diskfile = create_mock_diskfile();

	// Make maybe_get_diskfile_history return undefined the first time
	mock_zzz.maybe_get_diskfile_history.mockReturnValueOnce(undefined!);

	// Create the editor state - this should create history in the constructor
	const editor_state = new Diskfile_Editor_State({
		zzz: mock_zzz as any,
		diskfile: mock_diskfile as any,
	});

	// Force access to ensure the private #ensure_history method is called
	editor_state.save_changes();

	// Verify create_diskfile_history was called with the correct path
	expect(mock_zzz.create_diskfile_history).toHaveBeenCalledWith(mock_diskfile.path);

	// Ensure editor_state was used in a meaningful way
	expect(editor_state.diskfile).toEqual(mock_diskfile);
});
