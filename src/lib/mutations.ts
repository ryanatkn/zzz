/**
 * Implementation of client-side mutations for handling action responses
 */
import type {Mutations} from '$lib/action_types.js';
import type {Mutation_Context} from '$lib/mutation.js';
import type {Api_Result} from './api.js';

/**
 * Implementation of client-side mutations for outgoing messages
 */
export const send_mutations: Mutations = {
	Action_Ping: (ctx) => {
		console.log('Ping sent', ctx.params);
		return {
			ok: true,
			status: 200,
			value: 'Ping sent',
		};
	},

	Action_Load_Session: (ctx) => {
		console.log('Loading session...');
		return {
			ok: true,
			status: 200,
			value: 'Loading session...',
		};
	},

	Action_Send_Prompt: (ctx) => {
		console.log('Sending prompt', ctx.params.completion_request?.prompt);
		return {
			ok: true,
			status: 200,
			value: 'Prompt sent',
		};
	},

	Action_Update_Diskfile: (ctx) => {
		console.log('Updating file', ctx.params.path);
		return 'File updated';
	},

	Action_Delete_Diskfile: (ctx) => {
		console.log('Deleting file', ctx.params.path);
		return 'File deleted';
	},

	Action_Create_Directory: (ctx) => {
		console.log('Creating directory', ctx.params.path);
		return 'Directory created';
	},
};

/**
 * Implementation of client-side mutations for incoming server messages
 */
export const receive_mutations: Mutations = {
	Action_Pong: (ctx) => {
		console.log('Pong received', ctx.params);
		return ctx.result;
	},

	Action_Loaded_Session: (ctx) => {
		console.log('Session loaded');
		return ctx.result;
	},

	Action_Completion_Response: (ctx) => {
		console.log('Received completion', ctx.params.completion_response);
		return ctx.result;
	},

	Action_Filer_Change: (ctx) => {
		console.log('File changed', ctx.params.change);
		return ctx.result;
	},
};

/**
 * Legacy mutations object for backwards compatibility
 * @deprecated Use send_mutations and receive_mutations instead
 */
export const mutations: Mutations = {
	...send_mutations,
	...receive_mutations,
};

/**
 * Helper to create a mutation context for a specific action
 */
export const create_action_mutation_context = <
	T_Params,
	T_Result extends void | Api_Result<unknown>,
>(
	action_name: string,
	params: T_Params,
	result: T_Result,
): Mutation_Context<T_Params, T_Result> => {
	return {
		action_name,
		params,
		result,
		after_mutation: undefined, // No-op implementation for simple cases
	};
};
