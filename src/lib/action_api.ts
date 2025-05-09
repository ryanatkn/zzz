import {Logger} from '@ryanatkn/belt/log.js';
import {DEV, BROWSER} from 'esm-env';

import type {Action_Method, Actions, Mutations} from '$lib/action_metatypes.js';
import {create_mutation_context} from '$lib/mutation.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import type {Api_Client} from '$lib/api_client.js';

// TODO extensible

const log = new Logger();

export type Create_Actions_Client = (method: Action_Method) => Api_Client | null;

/**
 * Creates an Actions interface implementation using mutations and an API client.
 *
 * @param ui The UI state container
 * @param mutations The mutation handlers for each action
 * @param create_client Function to create an API client for a specific action
 * @returns An Actions implementation using a Proxy
 */
export const create_actions = (
	zzz: Zzz,
	mutations: Mutations,
	create_client: Create_Actions_Client,
): Actions => {
	const actions: Actions = new Proxy(Object.create(null), {
		get: (_target, method: Action_Method) => async (params: unknown) => {
			log.debug(...to_logged_args(method, params));

			const client = create_client(method);

			const mutation = mutations[method];

			if (!mutation) {
				if (DEV) {
					throw Error(`missing mutation for action '${method}'`);
				}
				log.warn('invoking action with no mutation', method, params);
				return client?.invoke(method, params);
			}
			const result = client ? await client.invoke(method, params) : undefined;
			const {ctx, flush_after_mutation} = create_mutation_context(
				zzz,
				method,
				params,
				result,
				actions,
			);
			const returned = mutation(ctx);
			void flush_after_mutation(); // TODO sequence across multiple mutations?
			return returned;
		},
	});
	return actions;
};

/**
 * Formats an action name and params for logging.
 */
const to_logged_args = (method: Action_Method, params: unknown): Array<any> => {
	const args = to_logged_method(method);
	if (params !== undefined) args.push(params); // print null but not undefined
	return args;
};

/**
 * Formats an action name for logging with color in browsers.
 */
const to_logged_method = (method: Action_Method): Array<any> =>
	BROWSER && DEV
		? [
				'%c[actions.%c' + method + '%c]',
				'color: gray',
				'color: magenta; font-weight: bold',
				'color: gray',
			]
		: ['[actions.' + method + ']'];
