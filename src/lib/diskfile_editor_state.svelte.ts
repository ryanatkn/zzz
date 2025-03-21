import {encode as tokenize} from 'gpt-tokenizer';

import type {Diskfile} from '$lib/diskfile.svelte.js';
import type {Diskfile_Path} from '$lib/diskfile_types.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import type {Diskfile_History, History_Entry} from '$lib/diskfile_history.svelte.js';
import type {Uuid} from '$lib/zod_helpers.js';

/**
 * Manages the editor state for a diskfile
 */
export class Diskfile_Editor_State {
	zzz: Zzz;
	diskfile: Diskfile = $state()!;

	// Store the ID of the unsaved edit entry
	unsaved_edit_entry_id: Uuid | null = $state(null);

	// Track which history entry is currently selected in the UI
	selected_history_entry_id: Uuid | null = $state(null);

	// Original content derived from diskfile.content, will update when file changes on disk
	original_content: string | null = $derived(this.diskfile.content);

	// Pure lookup of history from diskfile path - doesn't create anything
	history: Diskfile_History | undefined = $derived.by(() =>
		this.zzz.maybe_get_diskfile_history(this.diskfile.path),
	);

	// Provide access to history entries if history exists, otherwise empty array
	content_history: Array<History_Entry> = $derived(this.history?.entries || []);

	// Private content property - stores the actual content being edited
	#content: string = $state('');

	// Used to track if the user has edited the content
	content_was_modified_by_user: boolean = $state(false);

	// Track disk changes
	disk_changed: boolean = $state(false);
	last_seen_disk_content: string | null = $state(null);
	disk_content: string | null = $state(null);

	// Determines which entries content-match the current content
	content_matching_entry_ids: Array<Uuid> = $derived(
		this.content_history
			.filter((entry) => entry.content === this.updated_content)
			.map((entry) => entry.id),
	);

	// Getter/setter for updated_content
	get updated_content(): string {
		return this.#content;
	}

	set updated_content(value: string) {
		const content_changed = value !== this.#content;

		// Always update content
		this.#content = value;

		// Mark as modified only if different from original
		this.content_was_modified_by_user = value !== this.original_content;

		// Only update history if content actually changed
		if (content_changed) {
			this.#update_history_entry();
		}
	}

	// Basic derived states
	has_changes = $derived.by(() => this.updated_content !== this.original_content);
	path: Diskfile_Path = $derived.by(() => this.diskfile.path);

	// Length-related calculations
	original_length = $derived.by(() => this.original_content?.length ?? 0);
	updated_length = $derived(this.updated_content.length);
	length_diff = $derived(this.updated_length - this.original_length);
	length_diff_percent = $derived(
		this.original_length > 0 ? Math.round((this.length_diff / this.original_length) * 100) : 100,
	);

	// Token-related calculations
	original_tokens = $derived.by(() =>
		this.original_content ? tokenize(this.original_content) : [],
	);
	updated_tokens = $derived(tokenize(this.updated_content));
	original_token_count = $derived(this.original_tokens.length);
	updated_token_count = $derived(this.updated_tokens.length);
	token_diff = $derived(this.updated_token_count - this.original_token_count);
	token_diff_percent = $derived(
		this.original_token_count > 0
			? Math.round((this.token_diff / this.original_token_count) * 100)
			: 100,
	);

	constructor(options: {zzz: Zzz; diskfile: Diskfile}) {
		this.zzz = options.zzz;
		this.diskfile = options.diskfile;

		// Initialize content
		this.#content = this.original_content ?? '';

		// Set initial last_seen_disk_content
		this.last_seen_disk_content = this.diskfile.content;

		// Create initial history entry if needed
		if (this.original_content !== null) {
			const history = this.#ensure_history();

			// Only add entry if needed
			if (history.entries.length === 0) {
				history.add_entry(this.original_content);
			}

			// Always select the current entry when initializing
			if (history.current_entry) {
				this.selected_history_entry_id = history.current_entry.id;
			}
		}
	}

	/**
	 * Ensures a history object exists for the current file
	 * @returns The existing or newly created history object
	 */
	#ensure_history(): Diskfile_History {
		let history = this.zzz.maybe_get_diskfile_history(this.path);
		if (!history) {
			history = this.zzz.create_diskfile_history(this.path);
		}
		return history;
	}

	/**
	 * Updates existing history entry or creates a new one based on the current content
	 */
	#update_history_entry(): void {
		const history = this.#ensure_history();
		const matches_original = this.#content === this.original_content;

		// If content matches original, remove any unsaved entry
		if (matches_original) {
			if (this.unsaved_edit_entry_id) {
				const entry_index = history.entries.findIndex(
					(entry) => entry.id === this.unsaved_edit_entry_id,
				);
				if (entry_index !== -1) {
					history.entries.splice(entry_index, 1);
				}

				this.unsaved_edit_entry_id = null;

				// Instead of clearing selection entirely, select the most recent entry
				if (history.current_entry) {
					this.selected_history_entry_id = history.current_entry.id;
				} else {
					this.selected_history_entry_id = null;
				}
			}
			return;
		}

		// If we're currently editing an unsaved entry, update it
		if (this.unsaved_edit_entry_id) {
			const unsaved_entry = history.find_entry_by_id(this.unsaved_edit_entry_id);
			if (unsaved_entry) {
				unsaved_entry.content = this.#content;
				this.selected_history_entry_id = this.unsaved_edit_entry_id;
				return;
			}
		}

		// Look for an existing history entry with matching content before creating a new one
		const matching_entry = history.entries.find(
			(entry) => entry.content === this.#content && !entry.is_unsaved_edit,
		);

		if (matching_entry) {
			// Found a matching entry, select it instead of creating a new one
			this.selected_history_entry_id = matching_entry.id;
			return;
		}

		// Create a new unsaved entry
		const new_entry = history.add_entry(this.#content, {
			created: Date.now(),
			label: 'Unsaved edit',
			is_unsaved_edit: true,
		});

		this.unsaved_edit_entry_id = new_entry.id;
		this.selected_history_entry_id = new_entry.id;
	}

	/**
	 * Reset the editor state to match the current diskfile content
	 */
	reset(): void {
		// Set content directly without marking as user-modified
		this.#content = this.original_content ?? '';

		this.disk_changed = false;
		this.last_seen_disk_content = this.diskfile.content;
		this.disk_content = null;
		this.content_was_modified_by_user = false;

		// Reset the unsaved edit entry
		if (this.unsaved_edit_entry_id) {
			const history = this.history;
			if (history) {
				const existing_entry = history.find_entry_by_id(this.unsaved_edit_entry_id);
				if (existing_entry) {
					existing_entry.is_unsaved_edit = false;
				}
			}
			this.unsaved_edit_entry_id = null;
		}

		// Clear selection
		this.selected_history_entry_id = null;
	}

	/**
	 * Save changes to the diskfile
	 */
	save_changes(): boolean {
		if (!this.has_changes) return false;

		const history = this.#ensure_history();

		// Remove any entries that have the unsaved flag
		if (history.entries.length > 0) {
			const clean_entries = history.entries.filter((entry) => !entry.is_unsaved_edit);
			history.entries = clean_entries;
		}

		// Add a new entry for the saved content
		const entry = history.add_entry(this.updated_content);

		// Save to the file
		this.zzz.diskfiles.update(this.path, this.updated_content);

		// Update last seen content after saving
		this.last_seen_disk_content = this.updated_content;
		this.disk_changed = false;
		this.disk_content = null;
		this.content_was_modified_by_user = false;

		// Clear unsaved edit reference
		this.unsaved_edit_entry_id = null;

		// Set selection to the newly saved entry
		this.selected_history_entry_id = entry.id;

		return true;
	}

	/**
	 * Set content from history entry
	 */
	set_content_from_history(id: Uuid): void {
		const history = this.history;
		if (!history) return;

		const content = history.get_content(id);
		// Ensure we handle empty string case properly by checking for null specifically
		if (content !== null) {
			// Track which history entry is selected
			this.selected_history_entry_id = id;

			// Set content directly - will be marked as modified only if edited
			this.#content = content;
			this.content_was_modified_by_user = content !== this.original_content;

			// If we select an entry that has unsaved changes, update the unsaved entry reference
			const selected_entry = history.find_entry_by_id(id);
			if (selected_entry?.is_unsaved_edit) {
				this.unsaved_edit_entry_id = id;
			} else {
				// Clear unsaved entry reference for non-unsaved entries
				this.unsaved_edit_entry_id = null;
			}
		}
	}

	/**
	 * Update the diskfile reference
	 * This allows reusing the same editor state instance with a new diskfile
	 */
	update_diskfile(diskfile: Diskfile): void {
		if (this.diskfile.id === diskfile.id) return;

		// Store the new diskfile
		this.diskfile = diskfile;

		// Reset the editor state
		this.reset();

		// Ensure history is created for the new diskfile
		if (this.original_content !== null) {
			const history = this.#ensure_history();

			// Only add an entry if there's no history yet for this file
			if (history.entries.length === 0) {
				history.add_entry(this.original_content);
			}

			// Always select the current entry when switching files
			if (history.current_entry) {
				this.selected_history_entry_id = history.current_entry.id;
			}
		}
	}

	/**
	 * Check if the diskfile content has changed on disk
	 * Call this when receiving file updates from the server
	 */
	check_disk_changes(): void {
		// Only check if we have both the current and previous content
		if (this.diskfile.content === null || this.last_seen_disk_content === null) {
			return;
		}

		// If content hasn't changed from what we last saw
		if (this.diskfile.content === this.last_seen_disk_content) {
			// Handle case where file reverted to previous content
			if (this.disk_changed) {
				this.disk_changed = false;
				this.disk_content = null;
			}
			return;
		}

		// If the editor content has not been modified by the user or matches the new content on disk,
		// we can safely update without showing a notification
		if (!this.content_was_modified_by_user || this.updated_content === this.diskfile.content) {
			// Auto-update the editor content to match the new disk content without marking as user-modified
			this.#content = this.diskfile.content || '';

			// Add to history with disk change flag
			const disk_entry = this.#ensure_history().add_entry(this.updated_content, {
				is_disk_change: true,
				label: 'Disk change',
			});

			// Select the disk change entry
			this.selected_history_entry_id = disk_entry.id;

			// Update tracking variables
			this.last_seen_disk_content = this.diskfile.content;
			this.disk_changed = false;
			this.disk_content = null;

			return;
		}

		// At this point we know:
		// 1. Disk content has changed from what we last saw
		// 2. User has made their own edits
		// 3. User's edits don't match what's now on disk

		// Show notification for user to decide
		this.disk_changed = true;
		this.disk_content = this.diskfile.content;
	}

	/**
	 * Accept changes from disk, updating the editor content
	 */
	accept_disk_changes(): void {
		if (this.disk_content === null) {
			return;
		}

		const history = this.#ensure_history();
		const now = Date.now();

		// Add current content to history with current timestamp
		history.add_entry(this.updated_content, {
			created: now,
		});

		// Update the editor content without marking as user-modified
		this.#content = this.disk_content;

		// Add the new content to history with incremented timestamp and special label
		const disk_entry = history.add_entry(this.updated_content, {
			created: now + 1,
			is_disk_change: true,
			label: 'Accepted disk change',
		});

		// Reset disk change tracking
		this.last_seen_disk_content = this.disk_content;
		this.disk_changed = false;
		this.disk_content = null;
		this.content_was_modified_by_user = false;

		// Clear any unsaved changes
		this.unsaved_edit_entry_id = null;

		// Select the disk change entry
		this.selected_history_entry_id = disk_entry.id;
	}

	/**
	 * Reject changes from disk, keeping current editor content
	 * but adding the disk change to history for reference
	 */
	reject_disk_changes(): void {
		// Add disk content to history as a reference point, but don't apply it
		if (this.disk_content !== null) {
			// Add the ignored disk content to history with special label
			this.#ensure_history().add_entry(this.disk_content, {
				created: Date.now(),
				is_disk_change: true,
				label: 'Ignored disk change',
			});
		}

		// Update tracking without changing editor content
		this.last_seen_disk_content = this.diskfile.content;
		this.disk_changed = false;
		this.disk_content = null;
	}

	/**
	 * Clear content history, keeping only the current state
	 */
	clear_history(): void {
		const history = this.history;
		if (history) {
			history.clear_except_current();

			// Clear selection since entries are gone
			this.selected_history_entry_id = null;
			this.unsaved_edit_entry_id = null;
		}
	}
}
