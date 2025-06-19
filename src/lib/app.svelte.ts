import {create_context} from '@ryanatkn/fuz/context_helpers.js';

import {Frontend, frontend_context, type Frontend_Options} from '$lib/frontend.svelte.js';
import {cell_classes} from '$lib/cell_classes.js';
import {frontend_action_handlers} from '$lib/frontend_action_handlers.js';
import {WEBSOCKET_URL, API_URL_FOR_HTTP_RPC} from '$lib/constants.js';

// TODO some of this is awkward -- the idea
// is that this `App` is specific to the Zzz frontend application,
// and each project can create its own like this, if desired, or use the Frontend directly some other way

// TODO use this instead of `frontend_context` in non-core usages for type safety
export const app_context: ReturnType<typeof create_context<App>> = frontend_context;

export interface App_Options extends Frontend_Options {} // eslint-disable-line @typescript-eslint/no-empty-object-type

/**
 * The `App` is the user's implementation of the Zzz client app.
 * It extends Zzz and should be able to customize as much as possible,
 * including both behaviors and types. (both a work in progress)
 */
export class App extends Frontend {
	constructor(options?: App_Options) {
		const o = {...options};
		if (!o.http_rpc_url) o.http_rpc_url = API_URL_FOR_HTTP_RPC;
		if (!o.socket_url) o.socket_url = WEBSOCKET_URL;
		if (!o.cell_classes) o.cell_classes = cell_classes;
		if (!o.action_handlers) o.action_handlers = frontend_action_handlers;
		super(o);
	}
}
