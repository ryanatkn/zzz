import {page} from '$app/state';
import {z} from 'zod';
import {goto} from '$app/navigation';
import {BROWSER} from 'esm-env';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';

export const Url_Params_Json = z.object({
	// No persisted state needed
});
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
	 * Update URL with parameter for the selected entity.
	 */
	async update_url(param_name: string, value: string | null | undefined): Promise<void> {
		if (!BROWSER) return;
		const url = new URL(window.location.href);
		if (value == null) {
			url.searchParams.delete(param_name);
		} else {
			url.searchParams.set(param_name, value);
		}
		return goto(url);
	}

	/**
	 * Get a parameter value from the URL.
	 */
	get_param(param_name: string): string | null {
		return page.url.searchParams.get(param_name);
	}

	/**
	 * Get a UUID parameter value from the URL, with validation
	 * @param param_name Name of the URL parameter
	 */
	get_uuid_param(param_name: string): Uuid | null {
		const param_value = this.get_param(param_name);
		if (!param_value) return null;

		const parsed_uuid = Uuid.safeParse(param_value);
		return parsed_uuid.success ? parsed_uuid.data : null;
	}
}
