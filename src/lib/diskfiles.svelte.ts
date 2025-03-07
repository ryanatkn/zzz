import {SvelteMap} from 'svelte/reactivity';
import {z} from 'zod';

import type {Message_Filer_Change} from '$lib/message_types.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Diskfile} from '$lib/diskfile.svelte.js';
import {Diskfile_Json, type Diskfile_Path, Source_File} from '$lib/diskfile_types.js';
import {source_file_to_diskfile_json} from '$lib/diskfile_helpers.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {cell_array} from '$lib/cell_helpers.js';

export const Diskfiles_Json = z
	.object({
		files: cell_array(
			z.array(Diskfile_Json).default(() => []),
			'Diskfile',
		),
		selected_file_id: Uuid.nullable().default(null),
	})
	.default(() => ({
		files: [], // TODO redundant with the above
		selected_file_id: null, // TODO redundant with the above
	}));

export type Diskfiles_Json = z.infer<typeof Diskfiles_Json>;

export interface Diskfiles_Options extends Cell_Options<typeof Diskfiles_Json> {}

export class Diskfiles extends Cell<typeof Diskfiles_Json> {
	files: Array<Diskfile> = $state([]);
	selected_file_id: Uuid | null = $state(null);

	// TODO these are managed incrementally instead of using `$derived`, which makes the code more efficient but harder to follow and more error prone, maybe rethink, or put additional abstraction around it for safeguards
	// Maps for lookup - separate from schema
	by_id: SvelteMap<Uuid, Diskfile> = new SvelteMap();
	by_path: SvelteMap<Diskfile_Path, Uuid> = new SvelteMap();

	non_external_files: Array<Diskfile> = $derived(this.files.filter((file) => !file.external));
	files_map: Map<string, Diskfile> = $derived(
		new Map(this.non_external_files.map((f) => [f.id, f])),
	);
	selected_file: Diskfile | null = $derived(
		this.selected_file_id && (this.files_map.get(this.selected_file_id) ?? null),
	);

	// TODO maybe don't duplicate this data?
	#source_files: SvelteMap<Diskfile_Path, Source_File> = new SvelteMap();

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

		for (const file of this.files) {
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
		// Use safeParse for robust error handling
		const parsed = Source_File.safeParse(message.source_file);

		if (!parsed.success) {
			console.error('Invalid source file received from server:', parsed.error);
			return; // Don't proceed with invalid data
		}

		const validated_source_file = parsed.data;

		// Store the parsed source file
		this.#source_files.set(validated_source_file.id, validated_source_file);

		switch (message.change.type) {
			case 'add': {
				const diskfile = this.#create_diskfile(validated_source_file);
				this.files.push(diskfile);
				this.by_id.set(diskfile.id, diskfile);
				this.by_path.set(diskfile.path, diskfile.id);
				break;
			}
			case 'change': {
				// Find existing diskfile by path
				const existing_diskfile = this.get_by_path(validated_source_file.id);

				if (existing_diskfile) {
					// Update the existing diskfile, preserving its ID
					const diskfile_json = source_file_to_diskfile_json(
						validated_source_file,
						existing_diskfile.id, // Pass the existing ID to maintain stability
					);

					// Only update changed properties, not the entire object
					// This preserves created timestamp and other stable properties
					existing_diskfile.set_json({
						...diskfile_json,
						created: existing_diskfile.created, // Preserve original creation date
					});
				} else {
					// If it doesn't exist yet, create a new one
					const diskfile = this.#create_diskfile(validated_source_file);
					this.files.push(diskfile);
					this.by_id.set(diskfile.id, diskfile);
					this.by_path.set(diskfile.path, diskfile.id);
				}
				break;
			}
			case 'delete': {
				const diskfile_id = this.by_path.get(validated_source_file.id);
				if (diskfile_id) {
					// Remove from the files array
					const index = this.files.findIndex((f) => f.id === diskfile_id);
					if (index >= 0) {
						this.files.splice(index, 1);
					}

					this.by_id.delete(diskfile_id);
					this.by_path.delete(validated_source_file.id);
					this.#source_files.delete(validated_source_file.id);
				}
				break;
			}
		}
	}

	#create_diskfile(source_file: Source_File): Diskfile {
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

	get_source_file(path: Diskfile_Path): Source_File | undefined {
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
