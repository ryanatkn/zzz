import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';

export const Ui_Json = z
	.object({
		show_main_dialog: z.boolean().default(false),
	})
	.default(() => ({
		show_main_dialog: false,
	}));

export type Ui_Json = z.infer<typeof Ui_Json>;

export interface Ui_Options extends Cell_Options<typeof Ui_Json> {}

export class Ui extends Cell<typeof Ui_Json> {
	show_main_dialog = $state(false);

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
}
