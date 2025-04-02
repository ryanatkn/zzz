import {encode as tokenize} from 'gpt-tokenizer';
import {z} from 'zod';
import {strip_start} from '@ryanatkn/belt/string.js';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Diskfile_Json, type Diskfile_Path, type Source_File} from '$lib/diskfile_types.js';
import {to_preview} from '$lib/helpers.js';
import type {Bit_Type} from '$lib/bit.svelte.js';

export interface Diskfile_Options extends Cell_Options<typeof Diskfile_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Diskfile extends Cell<typeof Diskfile_Json> {
	path: Diskfile_Path = $state()!;

	content: string | null = $state()!;

	readonly bit: Bit_Type | undefined = $derived(this.zzz.bits.find_bit_by_diskfile_path(this.path));

	// TODO @many add UI support for deps for module diskfiles (TS, Svelte, etc)
	dependents: Array<[Diskfile_Path, Source_File]> = $state([]); // TODO @many these need to be null for unknown file types (support JS modules, etc)
	dependencies: Array<[Diskfile_Path, Source_File]> = $state([]); // TODO @many these need to be null for unknown file types (support JS modules, etc)

	readonly dependencies_by_id: Map<Diskfile_Path, Source_File> = $derived(
		new Map(this.dependencies),
	);
	readonly dependents_by_id: Map<Diskfile_Path, Source_File> = $derived(new Map(this.dependents));

	readonly dependency_ids: Array<Diskfile_Path> = $derived(this.dependencies.map(([id]) => id));
	readonly dependent_ids: Array<Diskfile_Path> = $derived(this.dependents.map(([id]) => id));

	readonly has_dependencies: boolean = $derived(this.dependencies.length > 0);
	readonly has_dependents: boolean = $derived(this.dependents.length > 0);

	readonly dependencies_count: number = $derived(this.dependencies.length);
	readonly dependents_count: number = $derived(this.dependents.length);

	/** e.g. .zzz/foo/bar.json */
	readonly pathname: string | null | undefined = $derived(
		this.path && this.zzz.zzz_dir_parent && strip_start(this.path, this.zzz.zzz_dir_parent),
	);
	/** e.g. bar/foo.json */
	readonly path_relative: string | null | undefined = $derived(
		this.zzz.diskfiles.to_relative_path(this.path),
	);

	readonly size: number | null = $derived(this.content?.length ?? null);

	// TODO BLOCK maybe have a Bit for this? just for text files?
	readonly content_length: number = $derived(this.content?.length ?? 0);
	readonly content_tokens: Array<number> | null = $derived(
		this.content === null ? null : tokenize(this.content),
	);
	readonly content_token_count: number | undefined = $derived(this.content_tokens?.length);
	readonly content_preview: string = $derived(to_preview(this.content));

	constructor(options: Diskfile_Options) {
		super(Diskfile_Json, options);

		this.init();
	}
}

export const Diskfile_Schema = z.instanceof(Diskfile);
