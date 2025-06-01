import {noop} from '@ryanatkn/belt/function.js';

import type {Client_Action_Handlers} from '$lib/action_metatypes.js';

// TODO we may also want method-based or middleware-like APIs

/**
 * These map to message types, not action methods.
 */
export const client_action_handlers: Client_Action_Handlers = {
	ping_request: (ctx) => {
		console.log('Ping request sent', ctx);
		ctx.app.capabilities.handle_sent_ping(ctx.jsonrpc_message.id); // TODO BLOCK @api type safety
	},
	ping_response: (ctx) => {
		console.log('Ping response received', ctx);
		if ('todo') {
			ctx.app.capabilities.handle_received_ping(ctx.result.value.result.ping_id);
		} else {
			ctx.app.capabilities.handle_ping_error(ctx.jsonrpc_message.id, ctx.result.message);
		}
	},

	load_session_request: () => {
		console.log('Loading session...');
	},
	load_session_response: (ctx) => {
		console.log('Session loaded', ctx);
		if ('todo') {
			ctx.app.receive_session(ctx.result.value.result.data);
		} else {
			console.error('Error loading session', ctx);
		}
	},

	submit_completion_request: (ctx) => {
		console.log('Sending prompt', ctx.params.completion_request.prompt);
	},
	submit_completion_response: (ctx) => {
		console.log('Received completion', ctx.params.completion_request, ctx.result);
		if ('todo') {
			return ctx.result.value.result; // acts as a method call, no side effects here
		} else {
			console.error('Error with completion', ctx);
		}
	},

	update_diskfile_request: (ctx) => {
		console.log('Updating file', ctx.params.path);
	},
	update_diskfile_response: noop,

	delete_diskfile_request: (ctx) => {
		console.log('Deleting file', ctx.params.path);
	},
	delete_diskfile_response: noop,

	create_directory_request: (ctx) => {
		console.log('Creating directory', ctx.params.path);
	},
	create_directory_response: (ctx) => {
		console.log('Created directory', ctx);
	},

	filer_change: (ctx) => {
		console.log('File changed', ctx.params.change, ctx.result);
		ctx.app.diskfiles.handle_change(ctx.params);
	},

	toggle_main_menu: (ctx) => {
		console.log('Toggling main menu', ctx.params);
		return ctx.app.ui.toggle_main_menu(ctx.params);
	},
};
