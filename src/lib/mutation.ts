import type {Api_Result} from '$lib/api.js';
import type {Actions} from '$lib/action_types.js';
import type {App} from '$lib/app.svelte.js';

/**
 * Client-side mutation system for handling action responses.
 */

/**
 * Context provided to mutation handlers.
 */
export interface Mutation_Context<
	T_Params = unknown,
	T_Result extends Api_Result<unknown> | void = any,
> {
	/** Reference to the main application instance. */
	zzz: App;
	/** Name of the action being performed. */
	action_name: string;
	/** Parameters passed to the action. */
	params: T_Params;
	/** Result returned from the server. */
	result: T_Result;
	/** Actions dispatcher for triggering additional actions. */
	actions: Actions; // TODO @many generic probably
	/** Adds a callback hook that runs after mutation finishes. */
	after_mutation: After_Mutation | undefined;
}

/**
 * Mutation handler function type.
 * Returns void or Promise<void> to support async operations.
 */
export type Mutation<T_Params = any, T_Result extends Api_Result<unknown> | void = any> = (
	ctx: Mutation_Context<T_Params, T_Result>,
) => void;

/**
 * Type for registering callbacks to run after mutation completes.
 */
export type After_Mutation = (cb: After_Mutation_Callback) => void;

/**
 * Callback function type for after mutation hooks.
 */
export type After_Mutation_Callback = () => void | Promise<void>;

/**
 * Creates a mutation context with the provided parameters and
 * a function to flush after-mutation callbacks.
 */
export const create_mutation_context = <
	T_Context extends Mutation_Context<T_Params, T_Result>,
	T_Params = unknown,
	T_Result extends Api_Result<unknown> | void = any,
>(
	zzz: App,
	action_name: string,
	params: T_Params,
	result: T_Result,
	actions: Actions, // TODO @many generic probably
): {ctx: T_Context; flush_after_mutation: () => Promise<void>} => {
	const cbs: Array<After_Mutation_Callback> = [];

	const after_mutation: After_Mutation = (cb) => {
		cbs.push(cb);
	};

	const flush_after_mutation = async (): Promise<void> => {
		for (const cb of cbs) {
			const returned = cb();
			if (returned && 'then' in returned) {
				await returned; // eslint-disable-line no-await-in-loop
			}
		}
	};

	const ctx = {
		zzz,
		action_name,
		params,
		result,
		actions,
		after_mutation,
	} satisfies Mutation_Context<T_Params, T_Result> as T_Context;

	return {ctx, flush_after_mutation};
};
