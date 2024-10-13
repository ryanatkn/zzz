import {EMPTY_OBJECT} from '@ryanatkn/belt/object.js';
import {create_context} from '@ryanatkn/fuz/context_helpers.js';

import {Zzz_Data, type Zzz_Data_Json} from '$lib/zzz_data.svelte.js';

export const zzz_context = create_context(() => new Zzz());

export interface Zzz_Options {
	data?: Zzz_Data;
}

export interface Zzz_Json {
	data: Zzz_Data_Json;
}

export class Zzz {
	data: Zzz_Data = $state()!; // eslint-disable-line @typescript-eslint/no-unnecessary-type-assertion

	constructor(options: Zzz_Options = EMPTY_OBJECT) {
		this.data = options.data ?? new Zzz_Data();
	}

	toJSON(): Zzz_Json {
		return {
			data: this.data.toJSON(),
		};
	}
}
