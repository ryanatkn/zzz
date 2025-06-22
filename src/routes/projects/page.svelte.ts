import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Page_Json} from '$routes/projects/projects_schema.js';

export type Page_Options = Cell_Options<typeof Page_Json>;

/**
 * Represents a page in a project.
 */
export class Page extends Cell<typeof Page_Json> {
	path: string = $state()!;
	title: string = $state()!;
	content: string = $state()!;

	constructor(options: Page_Options) {
		super(Page_Json, options);
		this.init();
	}
}
