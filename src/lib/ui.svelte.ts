import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';

export const Ui_Json = z
	.object({
		show_main_dialog: z.boolean().default(false),
		show_sidebar: z.boolean().default(true),
	})
	.default(() => ({
		show_main_dialog: false,
		show_sidebar: true,
	}));
export type Ui_Json = z.infer<typeof Ui_Json>;
export type Ui_Json_Input = z.input<typeof Ui_Json>;

export interface Ui_Options extends Cell_Options<typeof Ui_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type
export class Ui extends Cell<typeof Ui_Json> {
	show_main_dialog = $state(false);
	show_sidebar = $state(true);

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
