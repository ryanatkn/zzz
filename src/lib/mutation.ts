import type {Action_Method} from '$lib/action_metatypes.js';
import type {Zzz} from '$lib/zzz.svelte.js';

/**
 * Client-side mutation system for handling action responses.
 * Mutations are synchronous functions that apply state changes to the client app
 * based on action requests or responses.
 */

/**
 * Context provided to mutation handlers.
 */
export interface Mutation_Context<T_App extends Zzz = Zzz, T_Params = unknown, T_Result = any> {
	/** Reference to the main application instance. */
	zzz: T_App;
	/** Name of the action being performed. */
	method: Action_Method;
	/** Parameters passed to the action. */
	params: T_Params;
	/** Result returned from the server. */
	result: T_Result;
	/** Adds a callback hook that runs after mutation finishes. */
	after_mutation: After_Mutation | undefined;
}

/**
 * Mutation handler function type.
 * Must be synchronous.
 */
export type Mutation<T_App extends Zzz = Zzz, T_Params = any, T_Result = any> = (
	ctx: Mutation_Context<T_App, T_Params, T_Result>,
) => any;

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
	T_App extends Zzz = Zzz,
	T_Params = unknown,
	T_Result = any,
>(
	zzz: T_App,
	method: Action_Method,
	params: T_Params,
	result: T_Result,
): {
	ctx: Mutation_Context<T_App, T_Params, T_Result>;
	flush_after_mutation: () => Promise<void>;
} => {
	const cbs: Array<After_Mutation_Callback> = [];

	const after_mutation: After_Mutation = (cb) => {
		cbs.push(cb);
	};

	const flush_after_mutation = async (): Promise<void> => {
		for (const cb of cbs) {
			await cb(); // eslint-disable-line no-await-in-loop
		}
	};

	const ctx = {
		zzz,
		method,
		params,
		result,
		after_mutation,
	} satisfies Mutation_Context<T_App, T_Params, T_Result>;

	return {ctx, flush_after_mutation};
};
