import {page} from '$app/state';
import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';

export const Url_Params_Json = z.object({});
export type Url_Params_Json = z.infer<typeof Url_Params_Json>;
export type Url_Params_Json_Input = z.input<typeof Url_Params_Json>;

export interface Url_Params_Options extends Cell_Options<typeof Url_Params_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

/**
 * Manages URL parameter synchronization.
 */
export class Url_Params extends Cell<typeof Url_Params_Json> {
	constructor(options: Url_Params_Options) {
		super(Url_Params_Json, options);
		this.init();
	}

	/**
	 * Get a parameter value from the URL.
	 */
	get_param(param_name: string): string | null {
		return page.params[param_name] || null;
	}

	/**
	 * Get a UUID parameter value from the URL, with validation.
	 */
	get_uuid_param(param_name: string): Uuid | null {
		const param_value = this.get_param(param_name);
		if (!param_value) return null;

		const parsed_uuid = Uuid.safeParse(param_value);
		return parsed_uuid.success ? parsed_uuid.data : null;
	}
}
