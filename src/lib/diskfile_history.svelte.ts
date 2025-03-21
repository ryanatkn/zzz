import {z} from 'zod';

import {Diskfile_Path} from '$lib/diskfile_types.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Uuid} from '$lib/zod_helpers.js';

/**
 * Schema for history entries
 */
export const History_Entry = z.object({
	id: Uuid.default(() => Uuid.parse(undefined)), // Add unique ID for each entry
	created: z.number(),
	content: z.string(),
	label: z.string().optional(),
	is_disk_change: z.boolean().default(false),
});
export type History_Entry = z.infer<typeof History_Entry>;

/**
 * Schema for the Diskfile_History cell
 */
export const Diskfile_History_Json = Cell_Json.extend({
	path: Diskfile_Path,
	entries: z.array(History_Entry).default(() => []),
	max_entries: z.number().default(100),
});
export type Diskfile_History_Json = z.infer<typeof Diskfile_History_Json>;

export interface Diskfile_History_Options extends Cell_Options<typeof Diskfile_History_Json> {}

/**
 * Stores edit history for a single diskfile
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
	 * Add a new history entry
	 */
	add_entry(
		content: string,
		options: {
			is_disk_change?: boolean;
			label?: string;
			created?: number;
		} = {},
	): History_Entry {
		// Don't add duplicate entries with the same content back-to-back
		if (this.current_entry && this.current_entry.content === content) {
			return this.current_entry;
		}

		const entry: History_Entry = {
			id: Uuid.parse(undefined),
			created: options.created ?? Date.now(),
			content,
			is_disk_change: options.is_disk_change ?? false,
		};

		if (options.label) {
			entry.label = options.label;
		}

		// Find the correct insertion point to maintain sort order (newest first)
		let insertion_index = 0;
		while (
			insertion_index < this.entries.length &&
			this.entries[insertion_index].created > entry.created
		) {
			insertion_index++;
		}

		// Insert the entry at the correct position
		const new_entries = [...this.entries];
		new_entries.splice(insertion_index, 0, entry);
		this.entries = new_entries;

		// Trim history if it exceeds max size - already sorted by creation time
		if (this.entries.length > this.max_entries) {
			this.entries = this.entries.slice(0, this.max_entries);
		}

		return entry;
	}

	/**
	 * Find a history entry by ID
	 */
	find_entry_by_id(id: Uuid): History_Entry | undefined {
		return this.entries.find((entry) => entry.id === id);
	}

	/**
	 * Get the content of a specific history entry
	 */
	get_content(id: Uuid): string | null {
		const entry = this.find_entry_by_id(id);
		return entry ? entry.content : null;
	}

	/**
	 * Clear all history entries except the most recent one by creation time
	 */
	clear_except_current(): void {
		if (this.entries.length <= 1) return;

		// Since entries are sorted by creation time (newest first),
		// we can just keep the first entry
		this.entries = this.entries.length ? [this.entries[0]] : [];
	}
}
