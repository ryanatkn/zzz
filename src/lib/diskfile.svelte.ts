import type {Source_File} from '@ryanatkn/gro/filer.js';
import type {Path_Id} from '@ryanatkn/gro/path.js';
import {format} from 'date-fns';
import {encode} from 'gpt-tokenizer';

// TODO upstream to Filer probably
export interface Source_File_Json {
	id: Path_Id;
	contents: string | null;
	external: boolean;
	ctime: number | null;
	mtime: number | null;
	dependents: Array<[Path_Id, Source_File]>;
	dependencies: Array<[Path_Id, Source_File]>;
	size?: number | undefined; // TODO BLOCK add to `Source_File`?
}

export interface Diskfile_Json {
	source_file: Source_File_Json;
}

export interface Diskfile_Options {
	data: Diskfile_Json;
}

// Constants for formatting
export const FILE_DATE_FORMAT = 'MMM d, yyyy HH:mm:ss';
export const FILE_TIME_FORMAT = 'HH:mm:ss';

export class Diskfile {
	// TODO better name?
	original: Source_File_Json = $state()!;

	id: Path_Id = $state()!;
	contents: string | null = $state()!;
	dependents: Map<Path_Id, Source_File> = $state()!;
	dependencies: Map<Path_Id, Source_File> = $state()!;
	ctime: number = $state()!;
	mtime: number = $state()!;
	size: number = $state(0);
	external: boolean = $state(false);

	// Derived properties
	modified_date: Date = $derived(new Date(this.mtime));
	modified_formatted_date: string = $derived(format(this.modified_date, FILE_DATE_FORMAT));
	modified_formatted_time: string = $derived(format(this.modified_date, FILE_TIME_FORMAT));

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

	has_dependencies: boolean = $derived(this.dependencies.size > 0);
	has_dependents: boolean = $derived(this.dependents.size > 0);

	dependencies_count: number = $derived(this.dependencies.size);
	dependents_count: number = $derived(this.dependents.size);

	constructor(options: Diskfile_Options) {
		const {
			data: {source_file},
		} = options;
		this.original = source_file;
		this.id = source_file.id;
		this.contents = source_file.contents;
		this.dependents = new Map(source_file.dependents);
		this.dependencies = new Map(source_file.dependencies);
		this.ctime = source_file.ctime ?? Date.now(); // Default to current time if null/undefined
		this.mtime = source_file.mtime ?? Date.now(); // Default to current time if null/undefined
		this.size = source_file.size ?? source_file.contents?.length ?? 0;
		this.external = source_file.external ?? false;
	}

	// Helper methods to get keys directly
	get dependency_ids(): Array<Path_Id> {
		return Array.from(this.dependencies.keys());
	}

	get dependent_ids(): Array<Path_Id> {
		return Array.from(this.dependents.keys());
	}

	toJSON(): Diskfile_Json {
		return {
			source_file: {
				id: this.id,
				contents: this.contents,
				ctime: this.ctime,
				mtime: this.mtime,
				size: this.size,
				dependents: Array.from(this.dependents),
				dependencies: Array.from(this.dependencies),
				external: this.external,
			},
		};
	}
}
