import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';

export const Ui_Json = Cell_Json.extend({
	show_main_dialog: z.boolean().default(false),
	show_sidebar: z.boolean().default(true),
	tutorial_for_database: z.boolean().default(true),
	tutorial_for_chats: z.boolean().default(true),
	tutorial_for_prompts: z.boolean().default(true),
	tutorial_for_diskfiles: z.boolean().default(true),
}).meta({cell_class_name: 'Ui'});
export type Ui_Json = z.infer<typeof Ui_Json>;
export type Ui_Json_Input = z.input<typeof Ui_Json>;

export interface Ui_Options extends Cell_Options<typeof Ui_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type
export class Ui extends Cell<typeof Ui_Json> {
	show_main_dialog: boolean = $state()!;
	show_sidebar: boolean = $state()!;
	tutorial_for_database: boolean = $state()!;
	tutorial_for_chats: boolean = $state()!;
	tutorial_for_prompts: boolean = $state()!;
	tutorial_for_diskfiles: boolean = $state()!;

	// TODO revisit this API, maybe with an associated attachment?
	/** Consumed by components like `Content_Editor` for focusing elements. */
	pending_element_to_focus_key: string | number | null = $state(null);

	constructor(options: Ui_Options) {
		super(Ui_Json, options);
		this.init();
	}

	// TODO think about the main menu allowing any components to add snippets
	/**
	 * Toggle the main menu visibility.
	 */
	toggle_main_menu(value: boolean = !this.show_main_dialog): boolean {
		this.show_main_dialog = value;
		return value;
	}

	/**
	 * Toggle the sidebar visibility.
	 */
	toggle_sidebar(value: boolean = !this.show_sidebar): boolean {
		this.show_sidebar = value;
		return value;
	}
}
