import {create_context} from '@ryanatkn/fuz/context_helpers.js';

import {Zzz, type Zzz_Options} from '$lib/zzz.svelte.js';
import {cell_classes} from '$lib/cell_classes.js';
import {receive_mutations, send_mutations} from '$lib/mutations.js';
import {WEBSOCKET_URL, API_URL} from '$lib/constants.js';

// TODO use this instead of `zzz_context` in non-core usages
export const app_context = create_context<App>();

/**
 * The `App` is the user's implementation of the Zzz client app.
 * It extends Zzz and should be able to customize as much as possible,
 * including both behaviors and types. (both a work in progress)
 */
export class App extends Zzz {
	constructor(options?: Zzz_Options) {
		const o = {...options};
		if (!o.api_url) o.api_url = API_URL;
		if (!o.socket_url) o.socket_url = WEBSOCKET_URL;
		if (!o.cell_classes) o.cell_classes = cell_classes;
		if (!o.send_mutations) o.send_mutations = send_mutations;
		if (!o.receive_mutations) o.receive_mutations = receive_mutations;
		super(o);
	}
}
