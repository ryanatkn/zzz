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
	 * The most recent history entry
	 */
	current_entry: History_Entry | null = $derived(
		this.entries.length > 0 ? this.entries[this.entries.length - 1] : null,
	);

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

		// Add entry to history
		this.entries = [...this.entries, entry];

		// Trim history if it exceeds max size
		if (this.entries.length > this.max_entries) {
			this.entries = this.entries.slice(this.entries.length - this.max_entries);
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
	 * Clear all history entries except the most recent one
	 */
	clear_except_current(): void {
		if (this.entries.length <= 1) return;
		this.entries = this.entries.length ? [this.entries[this.entries.length - 1]] : [];
	}
}
