import type {Mutations} from '$lib/action_types.js';

/**
 * Client-side mutations for handling action responses
 */

/**
 * Client-side mutations for outgoing messages.
 */
export const send_mutations: Mutations = {
	Action_Ping: (ctx) => {
		console.log('Ping sent', ctx.params);
	},

	Action_Load_Session: () => {
		console.log('Loading session...');
	},

	Action_Send_Prompt: (ctx) => {
		console.log('Sending prompt', ctx.params.completion_request.prompt);
	},

	Action_Update_Diskfile: (ctx) => {
		console.log('Updating file', ctx.params.path);
	},

	Action_Delete_Diskfile: (ctx) => {
		console.log('Deleting file', ctx.params.path);
	},

	Action_Create_Directory: (ctx) => {
		console.log('Creating directory', ctx.params.path);
	},
};

/**
 * Client-side mutations for incoming server messages.
 */
export const receive_mutations: Mutations = {
	Action_Pong: (ctx) => {
		console.log('Pong received', ctx.params);
		ctx.zzz.capabilities.receive_pong(ctx.params);
	},

	Action_Loaded_Session: (ctx) => {
		console.log('Session loaded');
		ctx.zzz.receive_session(ctx.params.data);
	},

	Action_Completion_Response: (ctx) => {
		console.log('Received completion', ctx.params.completion_response);
		ctx.zzz.receive_completion_response(ctx.params);
	},

	Action_Filer_Change: (ctx) => {
		console.log('File changed', ctx.params.change);
		ctx.zzz.diskfiles.handle_change(ctx.params);
	},
};
