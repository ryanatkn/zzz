import {Cell, type CellOptions} from '$lib/cell.svelte.js';
import {DomainJson} from '$routes/projects/projects_schema.js';

export type DomainOptions = CellOptions<typeof DomainJson>;

/**
 * Represents a domain in a project.
 */
export class Domain extends Cell<typeof DomainJson> {
	name: string = $state()!;
	status: 'active' | 'pending' | 'inactive' = $state()!;
	ssl: boolean = $state()!;

	constructor(options: DomainOptions) {
		super(DomainJson, options);
		this.init();
	}
}
