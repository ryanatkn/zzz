import {Logger} from '@ryanatkn/belt/log.js';
import {DEV, BROWSER} from 'esm-env';

import type {Action_Name, Actions, Mutations} from '$lib/action_types.js';
import {create_mutation_context, type Mutation} from '$lib/mutation.js';
import type {Zzz} from '$lib/zzz.svelte.js';

// TODO BLOCK EXTENSIONS

const log = new Logger();

export type Create_Actions_Client = (action_name: string) => Api_Client | null;

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
		get: (_target, action_name: Action_Name) => async (params: unknown) => {
			log.debug(...to_logged_args(action_name, params));

			const client = create_client(action_name);

			const mutation = mutations[action_name];

			if (!mutation) {
				if (DEV) {
					throw Error(`missing mutation for action '${action_name}'`);
				}
				log.warn('invoking action with no mutation', action_name, params);
				return client?.invoke(action_name, params);
			}
			const result = client ? await client.invoke(action_name, params) : null;
			const {ctx, flush_after_mutation} = create_mutation_context(
				zzz,
				action_name,
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
const to_logged_args = (action_name: string, params: unknown): any[] => {
	const args = to_logged_action_name(action_name);
	if (params !== undefined) args.push(params); // print null but not undefined
	return args;
};

/**
 * Formats an action name for logging with color in browsers.
 */
const to_logged_action_name = (action_name: string): any[] =>
	BROWSER && DEV
		? [
				'%c[actions.%c' + action_name + '%c]',
				'color: gray',
				'color: magenta; font-weight: bold',
				'color: gray',
			]
		: ['[actions.' + action_name + ']'];
