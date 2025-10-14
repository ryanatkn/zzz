import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';

// Browser tab schema with discriminated union for tab types
export const Browser_Tab_Json = Cell_Json.extend({
	title: z.string(),
	url: z.string(),
	selected: z.boolean().default(false),
	refresh_counter: z.number().default(0),
	type: z.enum(['raw', 'embedded_html', 'external_url']),
	// Optional content field for embedded HTML tabs
	content: z.string().optional(),
}).meta({cell_class_name: 'Browser_Tab'});
export type Browser_Tab_Json = z.infer<typeof Browser_Tab_Json>;
export type Browser_Tab_Json_Input = z.input<typeof Browser_Tab_Json>;

export type Browser_Tab_Options = Cell_Options<typeof Browser_Tab_Json>;

/**
 * Represents a browser tab with different content types.
 * The tab behavior is determined by the `type` field:
 * - "raw": Shows raw content within the browser
 * - "embedded_html": Shows HTML content from the `content` field
 * - "external_url": Loads content from an external URL
 */
export class Browser_Tab extends Cell<typeof Browser_Tab_Json> {
	title: string = $state()!;
	url: string = $state()!;
	selected: boolean = $state()!;
	refresh_counter: number = $state()!;
	type: 'raw' | 'embedded_html' | 'external_url' = $state()!;
	content?: string = $state();

	constructor(options: Browser_Tab_Options) {
		super(Browser_Tab_Json, options);
		this.init();
	}

	refresh(): void {
		this.refresh_counter++;
	}
}

export const Browser_Tab_Schema = z.instanceof(Browser_Tab);
