import {z} from 'zod';

import type {Message_Filer_Change} from '$lib/message_types.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Diskfile, Diskfile_Schema} from '$lib/diskfile.svelte.js';
import {Diskfile_Json, Diskfile_Path} from '$lib/diskfile_types.js';
import {source_file_to_diskfile_json} from '$lib/diskfile_helpers.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {cell_array, HANDLED} from '$lib/cell_helpers.js';
import {strip_start} from '@ryanatkn/belt/string.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {
	create_single_index,
	create_multi_index,
	create_derived_index,
} from '$lib/indexed_collection_helpers.js';

export const Diskfiles_Json = z
	.object({
		diskfiles: cell_array(
			z.array(Diskfile_Json).default(() => []),
			'Diskfile',
		),
		selected_file_id: Uuid.nullable().default(null),
	})
	.default(() => ({
		diskfiles: [],
		selected_file_id: null,
	}));

export type Diskfiles_Json = z.infer<typeof Diskfiles_Json>;

export interface Diskfiles_Options extends Cell_Options<typeof Diskfiles_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Diskfiles extends Cell<typeof Diskfiles_Json> {
	readonly items: Indexed_Collection<Diskfile> = new Indexed_Collection({
		indexes: [
			create_single_index({
				key: 'by_path',
				extractor: (file) => file.path,
				query_schema: z.string(),
				result_schema: Diskfile_Schema,
			}),

			create_multi_index({
				key: 'by_external_status',
				extractor: (file) => (file.external ? 'external' : 'non_external'),
				query_schema: z.enum(['external', 'non_external']),
				result_schema: Diskfile_Schema,
			}),

			create_multi_index({
				key: 'by_extension',
				extractor: (file) => {
					const match = /\.([^.]+)$/.exec(file.path);
					return match ? match[1].toLowerCase() : 'no_extension';
				},
				query_schema: z.string(),
				result_schema: Diskfile_Schema,
			}),

			create_derived_index({
				key: 'non_external_files',
				compute: (collection) => collection.where('by_external_status', 'non_external'),
				matches: (item) => !item.external,
				result_schema: Diskfile_Schema,
				onadd: (collection, item) => {
					if (!item.external) {
						collection.push(item);
					}
					return collection;
				},
				onremove: (collection, item) => {
					if (!item.external) {
						const index = collection.findIndex((f) => f.id === item.id);
						if (index !== -1) collection.splice(index, 1);
					}
					return collection;
				},
			}),
		],
	});

	selected_file_id: Uuid | null = $state(null);

	selected_file: Diskfile | null = $derived(
		this.selected_file_id ? (this.items.by_id.get(this.selected_file_id) ?? null) : null,
	);

	// Use the derived index directly
	non_external_diskfiles: Array<Diskfile> = $derived(this.items.get_derived('non_external_files'));

	onselect?: (diskfile: Diskfile) => void;

	constructor(options: Diskfiles_Options) {
		super(Diskfiles_Json, options);

		this.decoders = {
			diskfiles: (diskfiles) => {
				if (Array.isArray(diskfiles)) {
					this.items.clear();
					for (const diskfile_json of diskfiles) {
						this.add(diskfile_json);
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
					// Update the existing diskfile, preserving its id
					const diskfile_json = source_file_to_diskfile_json(
						validated_source_file,
						existing_diskfile.id, // Pass the existing id to maintain stability
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

	update(path: Diskfile_Path, content: string): void {
		this.zzz.messages.send({
			id: Uuid.parse(undefined),
			type: 'update_diskfile',
			path,
			content,
		});
	}

	delete(path: Diskfile_Path): void {
		this.zzz.messages.send({
			id: Uuid.parse(undefined),
			type: 'delete_diskfile',
			path,
		});
	}

	create_file(filename: string, content: string = ''): void {
		if (!this.zzz.zzz_dir) {
			throw new Error('Cannot create file: zzz_dir is not set');
		}

		// Create full path by joining zzz_dir with the filename
		const path = Diskfile_Path.parse(`${this.zzz.zzz_dir}${filename}`);

		// Reuse the update method which creates or updates files
		this.update(path, content);
	}

	create_directory(dirname: string): void {
		if (!this.zzz.zzz_dir) {
			throw new Error('Cannot create directory: zzz_dir is not set');
		}

		// Create full path by joining zzz_dir with the directory name
		const path = Diskfile_Path.parse(`${this.zzz.zzz_dir}${dirname}`);

		this.zzz.messages.send({
			id: Uuid.parse(undefined),
			type: 'create_directory',
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
	 * Select a diskfile by id. Default to the first file if `id` is `undefined`.
	 * If `id` is `null`, it selects no file.
	 */
	select(id: Uuid | null | undefined): void {
		this.selected_file_id = id === undefined ? (this.items.all[0]?.id ?? null) : id;
	}
}
