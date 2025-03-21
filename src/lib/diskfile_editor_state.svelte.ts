import {encode as tokenize} from 'gpt-tokenizer';

import type {Diskfile} from '$lib/diskfile.svelte.js';
import type {Diskfile_Path} from '$lib/diskfile_types.js';
import type {Zzz} from '$lib/zzz.svelte.js';

// TODO maybe make `Editor` or some other term a common pattern and remove the _State suffix

/**
 * Manages the editor state for a diskfile
 */
export class Diskfile_Editor_State {
	zzz: Zzz; // TODO make this a cell?

	diskfile: Diskfile = $state()!;

	// Original content derived from diskfile.content, will update when file changes on disk
	original_content: string | null = $derived(this.diskfile.content);

	// Private content property - stores the actual content being edited
	#content: string = $state('');

	// Used to track if the user has edited the content
	content_was_modified_by_user: boolean = $state(false);

	content_history: Array<{created: number; content: string}> = $state([]);
	discarded_content: string | null = $state(null);

	// Track disk changes
	disk_changed: boolean = $state(false);
	last_seen_disk_content: string | null = $state(null);
	disk_content: string | null = $state(null);

	// Getter/setter for updated_content
	get updated_content(): string {
		return this.#content;
	}

	set updated_content(value: string) {
		this.#content = value;
		this.content_was_modified_by_user = true;
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

		// Initialize with the current content
		this.reset();

		// Set initial last_seen_disk_content
		this.last_seen_disk_content = this.diskfile.content;
	}

	/**
	 * Reset the editor state to match the current diskfile content
	 */
	reset(): void {
		// Set content directly without marking as user-modified
		this.#content = this.original_content ?? '';
		this.content_history = [{created: Date.now(), content: this.updated_content}];
		this.discarded_content = null;
		this.disk_changed = false;
		this.last_seen_disk_content = this.diskfile.content;
		this.disk_content = null;
		this.content_was_modified_by_user = false;
	}

	/**
	 * Save changes to the diskfile
	 */
	save_changes(): boolean {
		if (!this.has_changes) return false;

		this.content_history.push({created: Date.now(), content: this.updated_content});
		this.zzz.diskfiles.update(this.path, this.updated_content);
		this.discarded_content = null;

		// Update last seen content after saving
		this.last_seen_disk_content = this.updated_content;
		this.disk_changed = false;
		this.disk_content = null;
		this.content_was_modified_by_user = false;

		return true;
	}

	/**
	 * Handle discarding or restoring changes
	 * @param new_value If empty, discard changes. Otherwise, restore to this value.
	 */
	discard_changes(new_value: string): void {
		// If we're restoring, the new value is the previously discarded content
		// If we're discarding, the new value is empty and we set updated_content to the original file content
		if (new_value) {
			// Use setter to track modification
			this.updated_content = new_value;
			this.discarded_content = null;
		} else {
			this.discarded_content = this.updated_content;
			// Set content directly without marking as user-modified
			this.#content = this.original_content ?? '';
			this.content_was_modified_by_user = false;
		}
	}

	/**
	 * Set content from history entry
	 */
	set_content_from_history(created: number): void {
		const entry = this.content_history.find((entry) => entry.created === created);
		if (entry) {
			// Use setter to track modification
			this.updated_content = entry.content;
			this.discarded_content = null;
		}
	}

	/**
	 * Update the diskfile reference and reset the state
	 * This allows reusing the same editor state instance with a new diskfile
	 */
	update_diskfile(diskfile: Diskfile): void {
		this.diskfile = diskfile;
		this.reset();
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

			// Add to history
			this.content_history.push({
				created: Date.now(),
				content: this.updated_content,
			});

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

		// Add current content to history with current timestamp
		const now = Date.now();
		this.content_history.push({created: now, content: this.updated_content});

		// Update the editor content without marking as user-modified
		this.#content = this.disk_content;

		// Add the new content to history with incremented timestamp to ensure uniqueness
		this.content_history.push({created: now + 1, content: this.updated_content});

		// Reset disk change tracking
		this.last_seen_disk_content = this.disk_content;
		this.disk_changed = false;
		this.disk_content = null;
		this.content_was_modified_by_user = false;
	}

	/**
	 * Reject changes from disk, keeping current editor content
	 * but adding the disk change to history for reference
	 */
	reject_disk_changes(): void {
		// Add disk content to history as a reference point, but don't apply it
		if (this.disk_content !== null) {
			// Create a unique timestamp
			const now = Date.now();

			// Add the ignored disk content to history
			this.content_history.push({
				created: now, // TODO how to get the actual created/updated from the diskfile?
				content: this.disk_content, // preserve exact content so it can be restored as requested
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
		// Keep only the current state in history
		this.content_history = [{created: Date.now(), content: this.updated_content}];
	}
}
