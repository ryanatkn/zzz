import {SvelteMap} from 'svelte/reactivity';
import type {Source_File as Gro_Source_File} from '@ryanatkn/gro/filer.js';
import {z} from 'zod';

import type {Message_Filer_Change} from '$lib/message_types.js';
import {Uuid} from '$lib/uuid.js';
import {Diskfile} from '$lib/diskfile.svelte.js';
import {
	Diskfile_Json,
	source_file_to_diskfile_json,
	type Diskfile_Path,
	assert_valid_source_file,
} from '$lib/diskfile_types.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';

export const Diskfiles_Json = z
	.object({
		files: z.array(Diskfile_Json).default(() => []),
	})
	.default(() => ({}));

export type Diskfiles_Json = z.infer<typeof Diskfiles_Json>;

export interface Diskfiles_Options extends Cell_Options<typeof Diskfiles_Json> {}

export class Diskfiles extends Cell<typeof Diskfiles_Json> {
	// Store Diskfile instances by unique uuid
	by_id: SvelteMap<Uuid, Diskfile> = new SvelteMap();

	// Store mapping from path to diskfile id (uuid)
	by_path: SvelteMap<Diskfile_Path, Uuid> = new SvelteMap();

	// Keep track of source files for reference - use the Gro type here
	#source_files: SvelteMap<Diskfile_Path, Gro_Source_File> = new SvelteMap();

	files: Array<Diskfile> = $derived(Array.from(this.by_id.values()));

	constructor(options: Diskfiles_Options) {
		super(Diskfiles_Json, options);
		this.init();
	}

	// Override the set_json to handle the special case of files
	override set_json(value?: z.input<typeof Diskfiles_Json>): void {
		const parsed = this.schema.parse(value);

		// Special handling for files array
		if (parsed.files.length) {
			for (const file_json of parsed.files) {
				const diskfile = new Diskfile({
					zzz: this.zzz,
					json: file_json,
				});
				this.by_id.set(diskfile.id, diskfile);
				this.by_path.set(diskfile.path, diskfile.id);
			}
		}
	}

	handle_change(message: Message_Filer_Change): void {
		const change = message.change;
		const source_file = message.source_file;

		// Use the helper function to validate the source file
		const validated_source_file = assert_valid_source_file(source_file as Gro_Source_File);

		switch (change.type) {
			case 'add': {
				this.#source_files.set(validated_source_file.id, source_file as Gro_Source_File);
				const diskfile = this.#create_diskfile(source_file as Gro_Source_File);
				this.by_id.set(diskfile.id, diskfile);
				this.by_path.set(diskfile.path, diskfile.id);
				break;
			}
			case 'change': {
				this.#source_files.set(validated_source_file.id, source_file as Gro_Source_File);
				const diskfile = this.#create_diskfile(source_file as Gro_Source_File);
				this.by_id.set(diskfile.id, diskfile);
				this.by_path.set(diskfile.path, diskfile.id);
				break;
			}
			case 'unlink': {
				this.#source_files.delete(validated_source_file.id);
				const diskfile_id = this.by_path.get(validated_source_file.id);
				if (diskfile_id) {
					this.by_id.delete(diskfile_id);
					this.by_path.delete(validated_source_file.id);
				}
				break;
			}
		}
	}

	#create_diskfile(source_file: Gro_Source_File): Diskfile {
		return new Diskfile({
			zzz: this.zzz,
			json: source_file_to_diskfile_json(source_file),
		});
	}

	update(path: Diskfile_Path, contents: string): void {
		this.zzz.messages.send({
			id: Uuid.parse(undefined),
			type: 'update_diskfile',
			path,
			contents,
		});
	}

	delete(path: Diskfile_Path): void {
		this.zzz.messages.send({
			id: Uuid.parse(undefined),
			type: 'delete_diskfile',
			path,
		});
	}

	get_source_file(path: Diskfile_Path): Gro_Source_File | undefined {
		return this.#source_files.get(path);
	}

	get_by_path(path: Diskfile_Path): Diskfile | undefined {
		const id = this.by_path.get(path);
		return id ? this.by_id.get(id) : undefined;
	}
}
