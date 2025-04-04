import {z} from 'zod';
import {EMPTY_OBJECT} from '@ryanatkn/belt/object.js';

import {Diskfile_Path} from '$lib/diskfile_types.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Uuid} from '$lib/zod_helpers.js';

/**
 * Schema for history entries.
 */
export const History_Entry = z.object({
	id: Uuid,
	created: z.number(),
	content: z.string(),
	label: z.string(),
	is_disk_change: z.boolean().default(false),
	is_unsaved_edit: z.boolean().default(false), // Indicates entries containing unsaved user edits
	is_original_state: z.boolean().default(false), // Indicates if this entry represents the original disk state
});
export type History_Entry = z.infer<typeof History_Entry>;

/**
 * Schema for the Diskfile_History cell.
 */
export const Diskfile_History_Json = Cell_Json.extend({
	path: Diskfile_Path,
	entries: z.array(History_Entry).default(() => []),
	max_entries: z.number().default(100), // TODO rename? `history_size`? `max_size`? `capacity`?
});
export type Diskfile_History_Json = z.infer<typeof Diskfile_History_Json>;

export type Diskfile_History_Options = Cell_Options<typeof Diskfile_History_Json>;

/**
 * Stores edit history for a single diskfile.
 */
export class Diskfile_History extends Cell<typeof Diskfile_History_Json> {
	path: Diskfile_Path = $state()!;
	entries: Array<History_Entry> = $state()!;
	max_entries: number = $state()!;

	/**
	 * The most recent history entry (by creation timestamp)
	 * Since entries are always kept sorted by creation time (newest first),
	 * the most recent is always the first element.
	 */
	current_entry: History_Entry | null = $derived(this.entries.length > 0 ? this.entries[0] : null);

	constructor(options: Diskfile_History_Options) {
		super(Diskfile_History_Json, options);
		this.init();
	}

	/**
	 * Add a new history entry.
	 */
	add_entry(
		content: string,
		options: {
			is_disk_change?: boolean;
			is_unsaved_edit?: boolean;
			is_original_state?: boolean;
			label?: string;
			created?: number;
		} = EMPTY_OBJECT,
	): History_Entry {
		// Don't add duplicate entries with the same content and metadata back-to-back
		if (
			this.current_entry &&
			this.current_entry.content === content &&
			this.#has_same_metadata(this.current_entry, options)
		) {
			return this.current_entry;
		}

		const entry: History_Entry = {
			id: Uuid.parse(undefined),
			created: options.created ?? Date.now(),
			content,
			label: options.label ?? '',
			is_disk_change: options.is_disk_change ?? false,
			is_unsaved_edit: options.is_unsaved_edit ?? false,
			is_original_state: options.is_original_state ?? false,
		};

		// Process the entries in a single operation
		let new_entries = [...this.entries];

		// Find the correct insertion point to maintain sort order (newest first)
		let insertion_index = 0;
		while (
			insertion_index < new_entries.length &&
			new_entries[insertion_index].created > entry.created
		) {
			insertion_index++;
		}

		// Insert the entry at the correct position
		new_entries.splice(insertion_index, 0, entry);

		// Trim history if it exceeds max size - already sorted by creation time
		if (new_entries.length > this.max_entries) {
			new_entries = new_entries.slice(0, this.max_entries);
		}

		// Assign entries only once
		this.entries = new_entries;

		return entry;
	}

	/**
	 * Compare entry metadata flags with options
	 */
	#has_same_metadata(
		entry: History_Entry,
		options: {
			is_disk_change?: boolean;
			is_unsaved_edit?: boolean;
			is_original_state?: boolean;
			label?: string;
		},
	): boolean {
		return (
			entry.is_disk_change === (options.is_disk_change ?? entry.is_disk_change) &&
			entry.is_unsaved_edit === (options.is_unsaved_edit ?? entry.is_unsaved_edit) &&
			entry.is_original_state === (options.is_original_state ?? entry.is_original_state) &&
			entry.label === (options.label ?? entry.label)
		);
	}

	// TODO maybe make a map for faster lookup?
	/**
	 * Find a history entry by id.
	 */
	find_entry_by_id(id: Uuid): History_Entry | undefined {
		return this.entries.find((entry) => entry.id === id);
	}

	/**
	 * Get the content of a specific history entry.
	 */
	get_content(id: Uuid): string | null {
		const entry = this.find_entry_by_id(id);
		return entry ? entry.content : null;
	}

	/**
	 * Clear all history entries except the most recent one by creation time
	 * and any entries that match the optional keep predicate.
	 */
	clear_except_current(keep?: (entry: History_Entry) => boolean): void {
		if (this.entries.length <= 1) return;

		// Get the current (most recent) entry
		const current = this.entries.length ? this.entries[0] : null;

		// Filter entries to keep
		this.entries = this.entries.filter((entry) => {
			// Always keep the current entry
			if (current && entry.id === current.id) return true;

			// Keep entries that match the predicate if provided
			return keep ? keep(entry) : false;
		});
	}
}
