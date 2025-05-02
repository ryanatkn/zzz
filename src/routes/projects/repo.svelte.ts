import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import type {Uuid} from '$lib/zod_helpers.js';
import {Repo_Json} from '$routes/projects/projects_schema.js';

// TODO schema and id probably
export interface Repo_Checkout {
	id: Uuid;
	path: string;
	label: string;
	tags: Array<string>;
}

export type Repo_Options = Cell_Options<typeof Repo_Json>;

export class Repo extends Cell<typeof Repo_Json> {
	git_url: string = $state()!;
	checkouts: Array<Repo_Checkout> = $state()!;

	constructor(options: Repo_Options) {
		super(Repo_Json, options);
		this.init();
	}
}
