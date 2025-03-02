import {SvelteMap} from 'svelte/reactivity';
import type {Source_File} from '@ryanatkn/gro/filer.js';
import type {Path_Id} from '@ryanatkn/gro/path.js';

import type {Message_Filer_Change} from '$lib/message.schema.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import {Uuid} from '$lib/uuid.js';

export class Files {
	readonly zzz: Zzz;

	by_id: SvelteMap<Path_Id, Source_File> = new SvelteMap();

	files: Array<Source_File> = $derived(Array.from(this.by_id.values()));

	constructor(zzz: Zzz) {
		this.zzz = zzz;
	}

	handle_change(message: Message_Filer_Change): void {
		const change = message.change;
		const file = message.source_file;
		switch (change.type) {
			case 'add': {
				this.by_id.set(file.id, file);
				break;
			}
			case 'change': {
				this.by_id.set(file.id, file);
				break;
			}
			case 'unlink': {
				this.by_id.delete(file.id);
				break;
			}
		}
	}

	update(file_id: Path_Id, contents: string): void {
		this.zzz.messages.send({
			id: Uuid.parse(undefined),
			type: 'update_file',
			file_id,
			contents,
		});
	}

	delete(file_id: Path_Id): void {
		this.zzz.messages.send({
			id: Uuid.parse(undefined),
			type: 'delete_file',
			file_id,
		});
	}
}
