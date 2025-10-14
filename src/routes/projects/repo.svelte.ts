import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Repo_Json, type Repo_Checkout} from '$routes/projects/projects_schema.js';

export type Repo_Options = Cell_Options<typeof Repo_Json>;

export class Repo extends Cell<typeof Repo_Json> {
	git_url: string = $state()!;
	checkouts: Array<Repo_Checkout> = $state()!;

	constructor(options: Repo_Options) {
		super(Repo_Json, options);
		this.init();
	}
}
