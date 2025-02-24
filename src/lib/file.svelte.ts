import type {Source_File} from '@ryanatkn/gro/filer.js';
import type {Path_Id} from '@ryanatkn/gro/path.js';

// TODO upstream to Filer probably
export interface Source_File_Json {
	id: Path_Id;
	contents: string | null;
	dependents: Array<[Path_Id, Source_File]>;
	dependencies: Array<[Path_Id, Source_File]>;
}

export interface File_Json {
	source_file: Source_File_Json;
}

export interface File_Options {
	data: File_Json;
}

export class File {
	// TODO better name?
	original: Source_File_Json = $state()!;

	id: Path_Id = $state()!;
	contents: string | null = $state()!;
	dependents: Map<Path_Id, Source_File> = $state()!;
	dependencies: Map<Path_Id, Source_File> = $state()!;

	// TODO what else, current text?

	constructor(options: File_Options) {
		const {
			data: {source_file},
		} = options;
		this.original = source_file;
		this.id = source_file.id;
		this.contents = source_file.contents;
		// TODO Serializable pattern with `to_json`, `from_json`, derived json/str? `toJSON` calls `to_json`, and the latter is abstract
		this.dependents = new Map(source_file.dependents);
		this.dependencies = new Map(source_file.dependencies);
	}

	toJSON(): File_Json {
		return {
			source_file: {
				id: this.id,
				contents: this.contents,
				dependents: Array.from(this.dependents),
				dependencies: Array.from(this.dependencies),
			},
		};
	}
}
