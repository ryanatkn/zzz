import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';

export const Ui_Json = Cell_Json.extend({
	show_main_dialog: z.boolean().default(false),
	show_sidebar: z.boolean().default(true),
});
export type Ui_Json = z.infer<typeof Ui_Json>;
export type Ui_Json_Input = z.input<typeof Ui_Json>;

export interface Ui_Options extends Cell_Options<typeof Ui_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type
export class Ui extends Cell<typeof Ui_Json> {
	show_main_dialog = $state(false);
	show_sidebar = $state(true);

	// TODO revisit this API, maybe with an associated attachment?
	/** Consumed by components like `Content_Editor` for focusing elements. */
	pending_element_to_focus_key: string | number | null = $state(null);

	constructor(options: Ui_Options) {
		super(Ui_Json, options);
		this.init();
	}

	/**
	 * Toggle the main menu visibility
	 */
	toggle_main_menu(value: boolean = !this.show_main_dialog): boolean {
		this.show_main_dialog = value;
		return value;
	}

	/**
	 * Toggle the sidebar visibility
	 */
	toggle_sidebar(value: boolean = !this.show_sidebar): boolean {
		this.show_sidebar = value;
		return value;
	}
}
