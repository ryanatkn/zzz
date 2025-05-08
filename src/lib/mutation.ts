import type {Api_Result} from '$lib/api.js';
import type {Actions} from '$lib/action_types.js';

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
	/** Name of the action being performed. */
	action_name: string;
	/** Parameters passed to the action. */
	params: T_Params;
	/** Result returned from the server. */
	result: T_Result;
	/** Actions dispatcher for triggering additional actions. */
	actions?: Actions;
	/** Adds a callback hook that runs after mutation finishes. */
	after_mutation: After_Mutation | undefined;
}

/**
 * Mutation handler function type.
 */
export type Mutation<
	T_Params = unknown,
	T_Result extends Api_Result<unknown> | void = any,
	T_Return = any,
> = (ctx: Mutation_Context<T_Params, T_Result>) => T_Return;

/**
 * Type for registering callbacks to run after mutation completes
 */
export type After_Mutation = (cb: After_Mutation_Callback) => void;

/**
 * Callback function type for after mutation hooks
 */
export type After_Mutation_Callback = () => void | Promise<void>;

/**
 * Creates a mutation context with the provided parameters and a function to flush after-mutation callbacks
 */
export const create_mutation_context = <
	T_Context extends Mutation_Context<T_Params, T_Result>,
	T_Params = unknown,
	T_Result extends Api_Result<unknown> | void = any,
>(
	action_name: string,
	params: T_Params,
	result: T_Result,
	actions?: Actions,
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

	const ctx: Mutation_Context<T_Params, T_Result> = {
		action_name,
		params,
		result,
		actions,
		after_mutation,
	};

	return {ctx: ctx as T_Context, flush_after_mutation};
};
