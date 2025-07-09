// @slop Claude Sonnet 3.7

import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Diskfile_Tabs} from '$lib/diskfile_tabs.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Cell_Json} from '$lib/cell_types.js';

export const Diskfiles_Editor_Json = Cell_Json.extend({
	show_sort_controls: z.boolean().default(false),
});
export type Diskfiles_Editor_Json = z.infer<typeof Diskfiles_Editor_Json>;
export type Diskfiles_Editor_Json_Input = z.input<typeof Diskfiles_Editor_Json>;

export type Diskfiles_Editor_Options = Cell_Options<typeof Diskfiles_Editor_Json>;

/**
 * Editor state management for diskfiles.
 */
export class Diskfiles_Editor extends Cell<typeof Diskfiles_Editor_Json> {
	/** Controls visibility of sort controls in the file explorer. */
	show_sort_controls: boolean = $state(false);

	/** Tabs for managing the open diskfiles. */
	readonly tabs: Diskfile_Tabs = new Diskfile_Tabs({app: this.app});

	constructor(options: Diskfiles_Editor_Options) {
		super(Diskfiles_Editor_Json, options);
		this.init();
	}

	/**
	 * Opens a diskfile in preview mode.
	 */
	preview_diskfile(diskfile_id: Uuid): void {
		console.log('Diskfiles_Editor.preview_diskfile', {diskfile_id});
		this.tabs.preview_diskfile(diskfile_id);
	}

	/**
	 * Opens a diskfile in permanent mode.
	 */
	open_diskfile(diskfile_id: Uuid): void {
		console.log('Diskfiles_Editor.open_diskfile', {diskfile_id});
		this.tabs.open_diskfile(diskfile_id);
	}

	/**
	 * Reorders tabs.
	 */
	reorder_tabs(from_index: number, to_index: number): void {
		console.log('Diskfiles_Editor.reorder_tabs', {from_index, to_index});
		this.tabs.reorder_tabs(from_index, to_index);
	}

	/**
	 * Selects a tab by id.
	 */
	select_tab(tab_id: Uuid): void {
		console.log('Diskfiles_Editor.select_tab', {tab_id});
		this.tabs.select_tab(tab_id);
	}

	/**
	 * Closes a tab by id.
	 */
	close_tab(tab_id: Uuid): void {
		console.log('Diskfiles_Editor.close_tab', {tab_id});
		this.tabs.close_tab(tab_id);
	}

	/**
	 * Reopens the last closed tab.
	 */
	reopen_last_closed_tab(): void {
		console.log('Diskfiles_Editor.reopen_last_closed_tab');
		this.tabs.reopen_last_closed_tab();
	}

	/**
	 * Promotes the current preview tab to permanent.
	 */
	promote_preview_tab(): void {
		console.log('Diskfiles_Editor.promote_preview_tab');
		this.tabs.promote_preview_to_permanent();
	}

	/**
	 * Opens (makes permanent) a tab by id.
	 */
	open_tab(tab_id: Uuid): void {
		console.log('Diskfiles_Editor.open_tab', {tab_id});
		this.tabs.open_tab(tab_id);
	}

	/**
	 * Handles when a diskfile's content is modified.
	 */
	handle_file_modified(diskfile_id: Uuid): void {
		console.log('Diskfiles_Editor.handle_file_modified', {diskfile_id});
		// If the modified file is in a preview tab, promote it to permanent
		const tab = this.tabs.by_diskfile_id.get(diskfile_id);
		if (tab?.id === this.tabs.preview_tab_id) {
			this.tabs.preview_tab_id = null; // Convert to permanent by removing preview status
		}
	}

	/**
	 * Syncs the selected diskfile in diskfiles with the selected tab.
	 */
	sync_selected_file(): void {
		console.log('Diskfiles_Editor.sync_selected_file');
		const selected_diskfile_id = this.tabs.selected_diskfile_id;
		if (selected_diskfile_id) {
			this.app.diskfiles.selected_file_id = selected_diskfile_id;
		}
	}

	/**
	 * Toggles the visibility of sort controls in the file explorer.
	 */
	toggle_sort_controls(value = !this.show_sort_controls): void {
		this.show_sort_controls = value;
	}
}

export const Diskfiles_Editor_Schema = z.instanceof(Diskfiles_Editor);
