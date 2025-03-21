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

	original_content: string | null = $derived(this.diskfile.content);
	updated_content: string = $state('');
	content_history: Array<{created: number; content: string}> = $state([]);
	discarded_content: string | null = $state(null);

	// Track disk changes
	disk_changed: boolean = $state(false);
	last_seen_disk_content: string | null = $state(null);
	disk_content: string | null = $state(null);

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
		this.updated_content = this.original_content ?? '';
		this.content_history = [{created: Date.now(), content: this.updated_content}];
		this.discarded_content = null;
		this.disk_changed = false;
		this.last_seen_disk_content = this.diskfile.content;
		this.disk_content = null;
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
			this.updated_content = new_value;
			this.discarded_content = null;
		} else {
			this.discarded_content = this.updated_content;
			this.updated_content = this.original_content ?? '';
		}
	}

	/**
	 * Set content from history entry
	 */
	set_content_from_history(created: number): void {
		const entry = this.content_history.find((entry) => entry.created === created);
		if (entry) {
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

		// If the disk content now matches what's in the editor
		if (this.diskfile.content === this.updated_content) {
			// File on disk now matches what we're editing - no need for notification
			this.disk_changed = false;
			this.disk_content = null;
			// Update last seen content to match current disk content
			this.last_seen_disk_content = this.diskfile.content;
			return;
		}

		// Disk content changed to something different from both the last seen and editor content
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

		// Update the editor content
		this.updated_content = this.disk_content;

		// Add the new content to history with incremented timestamp to ensure uniqueness
		this.content_history.push({created: now + 1, content: this.disk_content});

		// Reset disk change tracking
		this.last_seen_disk_content = this.disk_content;
		this.disk_changed = false;
		this.disk_content = null;
	}

	/**
	 * Reject changes from disk, keeping current editor content
	 */
	reject_disk_changes(): void {
		// Update tracking without changing editor content
		this.last_seen_disk_content = this.diskfile.content;
		this.disk_changed = false;
		this.disk_content = null;
	}
}
