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
import {Cell, cell_array, type Cell_Options} from '$lib/cell.svelte.js';

export const Diskfiles_Json = z
	.object({
		files: cell_array(
			z.array(Diskfile_Json).default(() => []),
			'Diskfile',
		),
		selected_file_id: Uuid.nullable().default(null),
	})
	.default(() => ({
		files: [],
		selected_file_id: null,
	}));

export type Diskfiles_Json = z.infer<typeof Diskfiles_Json>;

export interface Diskfiles_Options extends Cell_Options<typeof Diskfiles_Json> {}

export class Diskfiles extends Cell<typeof Diskfiles_Json> {
	// Define property explicitly to match schema
	items: Array<Diskfile> = $state([]);
	selected_file_id: Uuid | null = $state(null);

	// TODO these are managed incrementally instead of using `$derived`, which makes the code more efficient but harder to follow and more error prone, maybe rethink, or put additional abstraction around it for safeguards
	// Maps for lookup - separate from schema
	by_id: SvelteMap<Uuid, Diskfile> = new SvelteMap();
	by_path: SvelteMap<Diskfile_Path, Uuid> = new SvelteMap();

	// Derived properties for file filtering and selection
	non_external_files: Array<Diskfile> = $derived(this.items.filter((file) => !file.external));
	files_map: Map<string, Diskfile> = $derived(
		new Map(this.non_external_files.map((f) => [f.id, f])),
	);
	selected_file: Diskfile | null = $derived(
		this.selected_file_id && (this.files_map.get(this.selected_file_id) ?? null),
	);

	// Private source files storage
	#source_files: SvelteMap<Diskfile_Path, Gro_Source_File> = new SvelteMap();

	constructor(options: Diskfiles_Options) {
		super(Diskfiles_Json, options);
		// Don't initialize maps from defaults, just init from json or leave them empty
		this.init();

		// Populate lookup maps after initialization
		this.#rebuild_indexes();
	}

	/**
	 * Rebuild the lookup indexes after files are loaded or changed
	 */
	#rebuild_indexes(): void {
		this.by_id.clear();
		this.by_path.clear();

		for (const file of this.items) {
			if (file.id && file.path) {
				this.by_id.set(file.id, file);
				this.by_path.set(file.path, file.id);
			}
		}
	}

	// Override set_json to handle the special case of rebuilding indexes
	override set_json(value?: z.input<typeof Diskfiles_Json>): void {
		// Let the parent handle the basic parsing and assignment
		super.set_json(value);

		// Then rebuild our indexes
		this.#rebuild_indexes();
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
				this.items.push(diskfile);
				this.by_id.set(diskfile.id, diskfile);
				this.by_path.set(diskfile.path, diskfile.id);
				break;
			}
			case 'change': {
				this.#source_files.set(validated_source_file.id, source_file as Gro_Source_File);
				const diskfile = this.#create_diskfile(source_file as Gro_Source_File);

				// Find and replace the existing diskfile if it exists
				const index = this.items.findIndex((f) => f.path === diskfile.path);
				if (index >= 0) {
					this.items[index] = diskfile;
				} else {
					this.items.push(diskfile);
				}

				this.by_id.set(diskfile.id, diskfile);
				this.by_path.set(diskfile.path, diskfile.id);
				break;
			}
			case 'delete': {
				this.#source_files.delete(validated_source_file.id);
				const diskfile_id = this.by_path.get(validated_source_file.id);
				if (diskfile_id) {
					// Remove from the files array
					const index = this.items.findIndex((f) => f.id === diskfile_id);
					if (index >= 0) {
						this.items.splice(index, 1);
					}

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

	/**
	 * Select a file by ID
	 */
	select_file(id: Uuid | null): void {
		this.selected_file_id = id;
	}
}
