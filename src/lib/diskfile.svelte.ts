import type {Source_File as Source_File_Type} from '@ryanatkn/gro/filer.js';
import {format} from 'date-fns';
import {encode} from 'gpt-tokenizer';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Diskfile_Json, type Diskfile_Path} from '$lib/diskfile_types.js';
import type {Datetime, Datetime_Now} from '$lib/zod_helpers.js';
import {Uuid} from '$lib/zod_helpers.js';

// Constants for formatting
export const FILE_DATE_FORMAT = 'MMM d, yyyy h:mm:ss a';
export const FILE_TIME_FORMAT = 'HH:mm:ss';

export interface Diskfile_Options extends Cell_Options<typeof Diskfile_Json> {}

export class Diskfile extends Cell<typeof Diskfile_Json> {
	// JSON-serialized properties
	id: Uuid = $state()!;
	path: Diskfile_Path = $state()!; // Renamed from file_id
	contents: string | null = $state()!;
	external: boolean = $state(false);
	created: Datetime_Now = $state()!;
	updated: Datetime = $state()!;
	dependents: Array<[Diskfile_Path, Source_File_Type]> = $state([]);
	dependencies: Array<[Diskfile_Path, Source_File_Type]> = $state([]);

	dependencies_by_id: Map<Diskfile_Path, Source_File_Type> = $derived(new Map(this.dependencies));
	dependents_by_id: Map<Diskfile_Path, Source_File_Type> = $derived(new Map(this.dependents));

	dependency_ids: Array<Diskfile_Path> = $derived(this.dependencies.map(([id]) => id));
	dependent_ids: Array<Diskfile_Path> = $derived(this.dependents.map(([id]) => id));

	created_date: Date = $derived(new Date(this.created));
	created_formatted_date: string = $derived(format(this.created_date, FILE_DATE_FORMAT));
	created_formatted_time: string = $derived(format(this.created_date, FILE_TIME_FORMAT));

	updated_date: Date | null = $derived(this.updated ? new Date(this.updated) : null);
	updated_formatted_date: string | null = $derived(
		this.updated_date ? format(this.updated_date, FILE_DATE_FORMAT) : null,
	);
	updated_formatted_time: string | null = $derived(
		this.updated_date ? format(this.updated_date, FILE_TIME_FORMAT) : null,
	);

	size: number | null = $derived(this.contents?.length ?? null);

	// TODO BLOCK maybe have a Bit for this? just for text files?
	content_length: number = $derived(this.contents?.length ?? 0);
	contents_tokens: Array<number> | null = $derived(
		this.contents === null ? null : encode(this.contents),
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
