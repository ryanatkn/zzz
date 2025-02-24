import {SvelteMap} from 'svelte/reactivity';
import type {Source_File} from '@ryanatkn/gro/filer.js';
import type {Path_Id} from '@ryanatkn/gro/path.js';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';

import type {Filer_Change_Message} from '$lib/zzz_message.js';
import {random_id} from '$lib/id.js';
import type {Zzz} from '$lib/zzz.svelte.js';

export class Files {
	readonly zzz: Zzz;

	readonly by_id: SvelteMap<Path_Id, Source_File> = new SvelteMap();

	constructor(zzz: Zzz) {
		this.zzz = zzz;
	}

	update(file_id: Path_Id, contents: string): void {
		const source_file = this.by_id.get(file_id);
		if (!source_file) {
			console.error('expected source file', file_id);
			return;
		}

		this.zzz.client.send({id: random_id(), type: 'update_file', file_id, contents});
	}

	delete(file_id: Path_Id): void {
		const source_file = this.by_id.get(file_id);
		if (!source_file) {
			console.error('expected source file', file_id);
			return;
		}

		this.zzz.client.send({id: random_id(), type: 'delete_file', file_id});
	}

	handle_change(message: Filer_Change_Message): void {
		const {change, source_file} = message;
		switch (change.type) {
			case 'add':
			case 'update': {
				this.by_id.set(source_file.id, source_file);
				break;
			}
			case 'delete': {
				this.by_id.delete(source_file.id);
				break;
			}
			default:
				throw new Unreachable_Error(change.type);
		}
	}
}
