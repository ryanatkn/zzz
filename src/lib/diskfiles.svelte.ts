import {SvelteMap} from 'svelte/reactivity';
import type {Source_File} from '@ryanatkn/gro/filer.js';
import type {Path_Id} from '@ryanatkn/gro/path.js';

import type {Message_Filer_Change} from '$lib/message.schema.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import {Uuid} from '$lib/uuid.js';
import {Diskfile} from '$lib/diskfile.svelte.js';

export class Diskfiles {
	readonly zzz: Zzz;

	// Store Diskfile instances instead of Source_File
	by_id: SvelteMap<Path_Id, Diskfile> = new SvelteMap();

	// Keep track of source files for reference
	#source_files: SvelteMap<Path_Id, Source_File> = new SvelteMap();

	files: Array<Diskfile> = $derived(Array.from(this.by_id.values()));

	constructor(zzz: Zzz) {
		this.zzz = zzz;
	}

	handle_change(message: Message_Filer_Change): void {
		const change = message.change;
		const source_file = message.source_file;

		switch (change.type) {
			case 'add': {
				this.#source_files.set(source_file.id, source_file);
				this.by_id.set(source_file.id, this.#create_diskfile(source_file));
				break;
			}
			case 'change': {
				this.#source_files.set(source_file.id, source_file);
				this.by_id.set(source_file.id, this.#create_diskfile(source_file));
				break;
			}
			case 'unlink': {
				this.#source_files.delete(source_file.id);
				this.by_id.delete(source_file.id);
				break;
			}
		}
	}

	#create_diskfile(source_file: Source_File): Diskfile {
		return new Diskfile({
			data: {
				source_file: {
					id: source_file.id,
					contents: source_file.contents,
					external: source_file.external,
					ctime: source_file.ctime,
					mtime: source_file.mtime,
					dependents: Array.from(source_file.dependents.entries()),
					dependencies: Array.from(source_file.dependencies.entries()),
					size: source_file.contents?.length ?? undefined,
				},
			},
		});
	}

	update(file_id: Path_Id, contents: string): void {
		this.zzz.messages.send({
			id: Uuid.parse(undefined),
			type: 'update_diskfile',
			file_id,
			contents,
		});
	}

	delete(file_id: Path_Id): void {
		this.zzz.messages.send({
			id: Uuid.parse(undefined),
			type: 'delete_diskfile',
			file_id,
		});
	}

	get_source_file(file_id: Path_Id): Source_File | undefined {
		return this.#source_files.get(file_id);
	}
}
