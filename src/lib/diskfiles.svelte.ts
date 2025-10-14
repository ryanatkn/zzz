import {z} from 'zod';

import {get_datetime_now, Path_With_Leading_Slash, Uuid} from '$lib/zod_helpers.js';
import {Diskfile} from '$lib/diskfile.svelte.js';
import {Diskfile_Json, Diskfile_Path, type Diskfile_Json_Input} from '$lib/diskfile_types.js';
import {disknode_to_diskfile_json, to_relative_path} from '$lib/diskfile_helpers.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {HANDLED} from '$lib/cell_helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {create_single_index, create_multi_index} from '$lib/indexed_collection_helpers.svelte.js';
import {Diskfiles_Editor} from '$lib/diskfiles_editor.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import type {Action_Inputs} from '$lib/action_collections.js';

export const Diskfiles_Json = Cell_Json.extend({
	diskfiles: z.array(Diskfile_Json).default(() => []),
	selected_file_id: Uuid.nullable().default(null),
}).meta({cell_class_name: 'Diskfiles'});
export type Diskfiles_Json = z.infer<typeof Diskfiles_Json>;
export type Diskfiles_Json_Input = z.input<typeof Diskfiles_Json>;

export interface Diskfiles_Options extends Cell_Options<typeof Diskfiles_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

export class Diskfiles extends Cell<typeof Diskfiles_Json> {
	readonly items: Indexed_Collection<Diskfile> = new Indexed_Collection({
		indexes: [
			create_single_index({
				key: 'by_path',
				extractor: (file) => file.path,
				query_schema: z.string(),
			}),

			create_multi_index({
				key: 'by_extension',
				extractor: (file) => {
					const match = /\.([^.]+)$/.exec(file.path);
					return match ? match[1].toLowerCase() : 'no_extension';
				},
				query_schema: z.string(),
			}),
		],
	});

	selected_file_id: Uuid | null = $state(null);

	readonly selected_file: Diskfile | null = $derived(
		this.selected_file_id ? (this.items.by_id.get(this.selected_file_id) ?? null) : null,
	);

	/** The editor for managing diskfiles editing state. */
	readonly editor: Diskfiles_Editor;

	constructor(options: Diskfiles_Options) {
		super(Diskfiles_Json, options);

		this.editor = new Diskfiles_Editor({app: this.app});

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

	handle_change(params: Action_Inputs['filer_change']): void {
		const validated_disknode = params.disknode;

		switch (params.change.type) {
			case 'add': {
				this.add(disknode_to_diskfile_json(validated_disknode));
				break;
			}
			case 'change': {
				const existing_diskfile = this.items.by_optional('by_path', validated_disknode.id);

				if (existing_diskfile) {
					const diskfile_json = disknode_to_diskfile_json(validated_disknode, existing_diskfile.id);

					existing_diskfile.set_json({
						...diskfile_json,
						// TODO hacky, should be handled more cleanly elsewhere
						created: existing_diskfile.created, // Preserve original creation date
						updated: get_datetime_now(), // TODO @many probably rely on the db to bump `updated`
					});
				} else {
					// If it doesn't exist yet, create a new one
					this.add(disknode_to_diskfile_json(validated_disknode));
				}
				break;
			}
			case 'delete': {
				const existing_diskfile = this.items.by_optional('by_path', validated_disknode.id);
				if (existing_diskfile) {
					this.items.remove(existing_diskfile.id);
				}
				break;
			}
		}
	}

	add(json: Diskfile_Json_Input, auto_select: boolean = true): Diskfile {
		const diskfile = new Diskfile({app: this.app, json});
		this.items.add(diskfile);

		if (auto_select && this.selected_file_id === null) {
			this.select(diskfile.id);
		}

		return diskfile;
	}

	async update(path: Diskfile_Path, content: string): Promise<void> {
		const result = await this.app.api.diskfile_update({path, content});
		// Handler already updated state on error
		if (!result.ok) return;
	}

	async delete(path: Diskfile_Path): Promise<void> {
		const result = await this.app.api.diskfile_delete({path});
		// Handler already updated state on error
		if (!result.ok) return;
	}

	async create_file(filename: string, content: string = ''): Promise<void> {
		if (!this.app.zzz_cache_dir) {
			throw new Error('cannot create file: zzz_cache_dir is not set');
		}

		// TODO @many how to handle paths? need some more structure to the way they're normalized and joined
		const path = Diskfile_Path.parse(
			`${this.app.zzz_cache_dir}${Path_With_Leading_Slash.parse(filename)}`,
		);

		// Reuse `update` which creates or updates files
		await this.update(path, content);
	}

	async create_directory(dirname: string): Promise<void> {
		if (!this.app.zzz_cache_dir) {
			throw new Error('cannot create directory: zzz_cache_dir is not set');
		}

		const path = Diskfile_Path.parse(`${this.app.zzz_cache_dir}${dirname}`);

		const result = await this.app.api.directory_create({path});
		// Handler already updated state on error
		if (!result.ok) return;
	}

	get_by_path(path: Diskfile_Path): Diskfile | undefined {
		return this.items.by_optional('by_path', path);
	}

	// TODO make this a derived property?
	/** The value `undefined` means uninitialized, `null` means loading, `''` means none */
	to_relative_path(path: string): string | null | undefined {
		const {zzz_cache_dir} = this.app;
		return zzz_cache_dir && to_relative_path(path, zzz_cache_dir);
	}

	/**
	 * Select a diskfile by id and also update the editor tabs.
	 * Default to the first file if `id` is `undefined`.
	 * If `id` is `null`, it selects no file.
	 * If `open_not_preview` is `true`, opens as a permanent tab, otherwise previews.
	 */
	select(id: Uuid | null | undefined, open_not_preview: boolean = false): void {
		if (id === undefined) {
			this.select_next();
		} else {
			this.selected_file_id = id;

			// Update the editor if a file is selected
			if (id !== null) {
				if (open_not_preview) {
					this.editor.open_diskfile(id);
				} else {
					this.editor.preview_diskfile(id);
				}
			}
		}
	}

	select_next(): void {
		const {by_id} = this.items;
		const next = by_id.values().next();
		this.select(next.value?.id ?? null);
	}
}
