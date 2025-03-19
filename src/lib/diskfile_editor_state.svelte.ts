import {encode as tokenize} from 'gpt-tokenizer';
import type {Diskfile} from '$lib/diskfile.svelte.js';
import type {Diskfile_Path} from '$lib/diskfile_types.js';
import type {Zzz} from '$lib/zzz.svelte.js';

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
	}

	/**
	 * Reset the editor state to match the current diskfile content
	 */
	reset(): void {
		this.updated_content = this.original_content ?? '';
		this.content_history = [{created: Date.now(), content: this.updated_content}];
		this.discarded_content = null;
	}

	/**
	 * Save changes to the diskfile
	 */
	save_changes(): boolean {
		if (!this.has_changes) return false;

		this.content_history.push({created: Date.now(), content: this.updated_content});
		this.zzz.diskfiles.update(this.path, this.updated_content);
		this.discarded_content = null;
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
}
