import {encode as tokenize} from 'gpt-tokenizer';
import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Diskfile_Json, type Diskfile_Path, type Source_File} from '$lib/diskfile_types.js';

export interface Diskfile_Options extends Cell_Options<typeof Diskfile_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Diskfile extends Cell<typeof Diskfile_Json> {
	// Serialized properties
	path: Diskfile_Path = $state()!;

	contents: string | null = $state()!;
	external: boolean = $state(false);
	dependents: Array<[Diskfile_Path, Source_File]> = $state([]); // TODO @many these need to be null for unknown file types (support JS modules, etc)
	dependencies: Array<[Diskfile_Path, Source_File]> = $state([]); // TODO @many these need to be null for unknown file types (support JS modules, etc)

	dependencies_by_id: Map<Diskfile_Path, Source_File> = $derived(new Map(this.dependencies));
	dependents_by_id: Map<Diskfile_Path, Source_File> = $derived(new Map(this.dependents));

	dependency_ids: Array<Diskfile_Path> = $derived(this.dependencies.map(([id]) => id));
	dependent_ids: Array<Diskfile_Path> = $derived(this.dependents.map(([id]) => id));

	// Derived properties
	path_relative: string | null | undefined = $derived(
		this.zzz.diskfiles.to_relative_path(this.path),
	);

	size: number | null = $derived(this.contents?.length ?? null);

	// TODO BLOCK maybe have a Bit for this? just for text files?
	content_length: number = $derived(this.contents?.length ?? 0);
	contents_tokens: Array<number> | null = $derived(
		this.contents === null ? null : tokenize(this.contents),
	);
	contents_token_count: number | undefined = $derived(this.contents_tokens?.length);

	content_preview: string = $derived(
		this.contents
			? this.contents.length > 50
				? this.contents.substring(0, 50) + '...'
				: this.contents
			: '',
	);

	has_dependencies: boolean = $derived(this.dependencies.length > 0);
	has_dependents: boolean = $derived(this.dependents.length > 0);

	dependencies_count: number = $derived(this.dependencies.length);
	dependents_count: number = $derived(this.dependents.length);

	constructor(options: Diskfile_Options) {
		super(Diskfile_Json, options);

		this.init();
	}
}

export const Diskfile_Schema = z.instanceof(Diskfile);
