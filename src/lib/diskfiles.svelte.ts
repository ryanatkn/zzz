import {z} from 'zod';

import type {Message_Filer_Change} from '$lib/message_types.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Diskfile} from '$lib/diskfile.svelte.js';
import {Diskfile_Json, type Diskfile_Path, Source_File} from '$lib/diskfile_types.js';
import {source_file_to_diskfile_json} from '$lib/diskfile_helpers.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {strip_start} from '@ryanatkn/belt/string.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';

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

export interface Diskfiles_Options extends Cell_Options<typeof Diskfiles_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

type Diskfile_Indexes = 'by_path';

export class Diskfiles extends Cell<typeof Diskfiles_Json> {
	readonly items: Indexed_Collection<Diskfile, Diskfile_Indexes> = new Indexed_Collection({
		indexes: [
			{
				key: 'by_path',
				extractor: (file) => file.path,
				multi: false, // One path maps to one file
			},
		],
	});

	selected_file_id: Uuid | null = $state(null);

	selected_file: Diskfile | null = $derived(
		this.selected_file_id ? (this.items.by_id.get(this.selected_file_id) ?? null) : null,
	);
	non_external_files: Array<Diskfile> = $derived(this.items.array.filter((file) => !file.external));
	onselect?: (file: Diskfile) => void;

	constructor(options: Diskfiles_Options) {
		super(Diskfiles_Json, options);

		this.decoders = {
			files: (files) => {
				if (Array.isArray(files)) {
					this.items.clear();
					for (const file_json of files) {
						const file = new Diskfile({zzz: this.zzz, json: file_json});
						this.items.add(file);
					}
				}
				return HANDLED;
			},
		};

		this.init();
	}

	handle_change(message: Message_Filer_Change): void {
		const validated_source_file = message.source_file;

		switch (message.change.type) {
			case 'add': {
				const diskfile = this.#create_diskfile(validated_source_file);
				this.items.add(diskfile);
				break;
			}
			case 'change': {
				// Find existing diskfile by path
				const path_index = this.items.single_indexes.by_path;
				if (!path_index) return;

				const existing_diskfile = path_index.get(validated_source_file.id);

				if (existing_diskfile) {
					// Update the existing diskfile, preserving its ID
					const diskfile_json = source_file_to_diskfile_json(
						validated_source_file,
						existing_diskfile.id, // Pass the existing ID to maintain stability
					);

					// Only update changed properties, not the entire object
					existing_diskfile.set_json({
						...diskfile_json,
						// TODO hacky, should be handled more cleanly elsewhere
						created: existing_diskfile.created, // Preserve original creation date
					});
				} else {
					// If it doesn't exist yet, create a new one
					const diskfile = this.#create_diskfile(validated_source_file);
					this.items.add(diskfile);
				}
				break;
			}
			case 'delete': {
				const path_index = this.items.single_indexes.by_path;
				if (!path_index) return;

				const existing_diskfile = path_index.get(validated_source_file.id);
				if (existing_diskfile) {
					this.items.remove(existing_diskfile.id);
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

	get_by_path(path: Diskfile_Path): Diskfile | undefined {
		return this.items.single_indexes.by_path?.get(path);
	}

	/** Like `zzz.zzz_dir`, `undefined` means uninitialized, `null` means loading, `''` means none */
	to_relative_path(path: string): string | null | undefined {
		const {zzz_dir} = this.zzz;
		return zzz_dir && strip_start(path, zzz_dir);
	}

	/**
	 * Select a file by ID
	 */
	select(id: Uuid | null): void {
		this.selected_file_id = id;
	}
}
