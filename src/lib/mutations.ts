import {noop} from '@ryanatkn/belt/function.js';

import type {Mutations} from '$lib/action_metatypes.js';

// TODO we may also want method-based or middleware-like APIs
/**
 * These map to message types, not action methods.
 */
export const mutations: Mutations = {
	ping_request: (ctx) => {
		console.log('Ping request sent', ctx);
		ctx.zzz.capabilities.handle_sent_ping(ctx.jsonrpc_message.id); // TODO BLOCK @api type safety
	},
	ping_response: (ctx) => {
		console.log('Ping response received', ctx.result);
		if (ctx.result.ok) {
			ctx.zzz.capabilities.handle_received_ping(ctx.result.value.result.params.ping_id);
		} else {
			ctx.zzz.capabilities.handle_ping_error(ctx.jsonrpc_message.id, ctx.result.message);
		}
	},

	load_session_request: () => {
		console.log('Loading session...');
	},
	load_session_response: (ctx) => {
		console.log('Session loaded', ctx.result);
		if (ctx.result.ok) {
			ctx.zzz.receive_session(ctx.result.value.result.data);
		} else {
			console.error('Error loading session', ctx.result);
		}
	},

	submit_completion_request: (ctx) => {
		console.log('Sending prompt', ctx.params.completion_request.prompt);
	},
	submit_completion_response: (ctx) => {
		console.log('Received completion', ctx.params.completion_request, ctx.result);
		ctx.zzz.receive_completion_response(ctx.result.data);
	},

	update_diskfile_request: (ctx) => {
		console.log('Updating file', ctx.params.path);
	},
	update_diskfile_response: noop,

	delete_diskfile_request: (ctx) => {
		console.log('Deleting file', ctx.params.path);
	},

	create_directory_request: (ctx) => {
		console.log('Creating directory', ctx.params.path);
	},
	create_directory_response: (ctx) => {
		console.log('Created directory', ctx.result.data);
	},

	filer_change: (ctx) => {
		console.log('File changed', ctx.params.change, ctx.result);
		ctx.zzz.diskfiles.handle_change(ctx.params);
	},

	toggle_main_menu: (ctx) => {
		console.log('Toggling main menu', ctx.params);
		return ctx.zzz.ui.toggle_main_menu(ctx.params);
	},
};
