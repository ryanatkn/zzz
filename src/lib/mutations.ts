import type {Mutations} from '$lib/action_metatypes.js';

/**
 * Client-side mutations for handling action responses.
 */

// TODO BLOCK should use the message type instead of the action method and have a single `Mutations`

/**
 * Client-side mutations for outgoing messages.
 */
export const send_mutations: Mutations = {
	ping: (ctx) => {
		console.log('Ping sent', ctx.params);
		ctx.zzz.capabilities.handle_sent_ping(ctx.params);
	},

	load_session: (ctx) => {
		console.log('Loading session...');
	},

	submit_completion: (ctx) => {
		console.log('Sending prompt', ctx.params.completion_request?.prompt);
	},

	update_diskfile: (ctx) => {
		console.log('Updating file', ctx.params.path);
	},

	delete_diskfile: (ctx) => {
		console.log('Deleting file', ctx.params.path);
	},

	create_directory: (ctx) => {
		console.log('Creating directory', ctx.params.path);
	},
};

/**
 * Client-side mutations for incoming server messages.
 */
export const receive_mutations: Mutations = {
	ping: (ctx) => {
		console.log('Pong received', ctx.params);
		ctx.zzz.capabilities.handle_received_ping(ctx.params);
	},

	load_session: (ctx) => {
		console.log('Session loaded');
		ctx.zzz.receive_session(ctx.params.data);
	},

	submit_completion: (ctx) => {
		console.log('Received completion', ctx.params.completion_response);
		ctx.zzz.receive_completion_response(ctx.params);
	},

	filer_change: (ctx) => {
		console.log('File changed', ctx.params.change);
		ctx.zzz.diskfiles.handle_change(ctx.params);
	},
};
