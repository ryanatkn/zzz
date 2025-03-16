import {z} from 'zod';

import type {Message_Filer_Change} from '$lib/message_types.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Diskfile} from '$lib/diskfile.svelte.js';
import {Diskfile_Json, type Diskfile_Path} from '$lib/diskfile_types.js';
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

// Define single index key for Diskfile - we only have a by_path single index
export type Diskfile_Single_Indexes = 'by_path';

// Define multi index keys for Diskfile - adding by_external_status for filtering
export type Diskfile_Multi_Indexes = 'by_external_status';

export class Diskfiles extends Cell<typeof Diskfiles_Json> {
	readonly items: Indexed_Collection<Diskfile, Diskfile_Single_Indexes, Diskfile_Multi_Indexes> =
		new Indexed_Collection({
			single_indexes: [
				{
					key: 'by_path',
					extractor: (file: Diskfile) => file.path,
				},
			],
			multi_indexes: [
				{
					key: 'by_external_status',
					extractor: (file: Diskfile) => (file.external ? 'external' : 'non_external'),
				},
			],
		});

	selected_file_id: Uuid | null = $state(null);

	selected_file: Diskfile | null = $derived(
		this.selected_file_id ? (this.items.by_id.get(this.selected_file_id) ?? null) : null,
	);

	// Use the multi-index query instead of filtering
	non_external_files: Array<Diskfile> = $derived(
		this.items.where('by_external_status', 'non_external'),
	);

	onselect?: (file: Diskfile) => void;

	constructor(options: Diskfiles_Options) {
		super(Diskfiles_Json, options);

		this.decoders = {
			files: (files) => {
				if (Array.isArray(files)) {
					this.items.clear();
					for (const file_json of files) {
						this.add(file_json);
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
				this.add(source_file_to_diskfile_json(validated_source_file));
				break;
			}
			case 'change': {
				// Find existing diskfile by path
				const existing_diskfile = this.items.by_optional('by_path', validated_source_file.id);

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
					this.add(source_file_to_diskfile_json(validated_source_file));
				}
				break;
			}
			case 'delete': {
				const existing_diskfile = this.items.by_optional('by_path', validated_source_file.id);
				if (existing_diskfile) {
					this.items.remove(existing_diskfile.id);
				}
				break;
			}
		}
	}

	add(json: Diskfile_Json): Diskfile {
		const diskfile = new Diskfile({zzz: this.zzz, json});
		this.items.add(diskfile);
		if (this.selected_file_id === null) {
			this.selected_file_id = diskfile.id;
		}
		return diskfile;
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
		return this.items.by_optional('by_path', path);
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
