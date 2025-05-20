import type {Mutations} from '$lib/action_metatypes.js';

export const mutations: Mutations = {
	ping_request: (ctx) => {
		console.log('Ping sent', ctx.params);
		ctx.zzz.capabilities.handle_sent_ping(ctx.params);
	},

	ping_response: (ctx) => {
		console.log('Pong received', ctx.params);
		ctx.zzz.capabilities.handle_received_ping(ctx.params);
	},

	load_session_request: (ctx) => {
		console.log('Loading session...');
	},

	load_session_response: (ctx) => {
		console.log('Session loaded');
		ctx.zzz.receive_session(ctx.params.data);
	},

	submit_completion_request: (ctx) => {
		console.log('Sending prompt', ctx.params.completion_request?.prompt);
	},

	submit_completion_response: (ctx) => {
		console.log('Received completion', ctx.params.completion_response);
		ctx.zzz.receive_completion_response(ctx.params);
	},

	update_diskfile_request: (ctx) => {
		console.log('Updating file', ctx.params.path);
	},

	delete_diskfile_request: (ctx) => {
		console.log('Deleting file', ctx.params.path);
	},

	create_directory_request: (ctx) => {
		console.log('Creating directory', ctx.params.path);
	},

	filer_change: (ctx) => {
		console.log('File changed', ctx.params.change);
		ctx.zzz.diskfiles.handle_change(ctx.params);
	},
};
