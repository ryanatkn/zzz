import {encode as tokenize} from 'gpt-tokenizer';
import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Diskfile_Json, type Diskfile_Path, type Source_File} from '$lib/diskfile_types.js';
import {strip_start} from '@ryanatkn/belt/string.js';

export interface Diskfile_Options extends Cell_Options<typeof Diskfile_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Diskfile extends Cell<typeof Diskfile_Json> {
	path: Diskfile_Path = $state()!;

	content: string | null = $state()!;
	external: boolean = $state(false);
	dependents: Array<[Diskfile_Path, Source_File]> = $state([]); // TODO @many these need to be null for unknown file types (support JS modules, etc)
	dependencies: Array<[Diskfile_Path, Source_File]> = $state([]); // TODO @many these need to be null for unknown file types (support JS modules, etc)

	dependencies_by_id: Map<Diskfile_Path, Source_File> = $derived(new Map(this.dependencies));
	dependents_by_id: Map<Diskfile_Path, Source_File> = $derived(new Map(this.dependents));

	dependency_ids: Array<Diskfile_Path> = $derived(this.dependencies.map(([id]) => id));
	dependent_ids: Array<Diskfile_Path> = $derived(this.dependents.map(([id]) => id));

	/** e.g. .zzz/foo/bar.json */
	pathname: string | null | undefined = $derived(
		this.path && this.zzz.zzz_dir_parent && strip_start(this.path, this.zzz.zzz_dir_parent),
	);
	/** e.g. bar/foo.json */
	path_relative: string | null | undefined = $derived(
		this.zzz.diskfiles.to_relative_path(this.path),
	);

	size: number | null = $derived(this.content?.length ?? null);

	// TODO BLOCK maybe have a Bit for this? just for text files?
	content_length: number = $derived(this.content?.length ?? 0);
	content_tokens: Array<number> | null = $derived(
		this.content === null ? null : tokenize(this.content),
	);
	content_token_count: number | undefined = $derived(this.content_tokens?.length);

	content_preview: string = $derived(
		this.content
			? this.content.length > 50
				? this.content.substring(0, 50) + '...'
				: this.content
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
