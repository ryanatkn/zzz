import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Domain_Json} from './projects_schema.js';

export type Domain_Options = Cell_Options<typeof Domain_Json>;

/**
 * Represents a domain in a project.
 */
export class Domain extends Cell<typeof Domain_Json> {
	name: string = $state()!;
	status: 'active' | 'pending' | 'inactive' = $state()!;
	ssl: boolean = $state()!;

	constructor(options: Domain_Options) {
		super(Domain_Json, options);
		this.init();
	}
}
