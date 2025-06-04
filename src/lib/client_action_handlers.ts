import {noop} from '@ryanatkn/belt/function.js';

import type {Client_Action_Handlers} from '$lib/client_action_types.js';

// TODO we may also want method-based or middleware-like APIs

/**
 * These map to message types, not action methods.
 */
export const client_action_handlers: Client_Action_Handlers = {
	ping: {
		send_request: (ctx) => {
			console.log('Ping request sent', ctx);
			ctx.app.capabilities.handle_sent_ping(ctx.jsonrpc_message.id); // TODO BLOCK @api type safety
		},
		receive_response: (ctx) => {
			console.log('Ping response received', ctx);
			if ('todo') {
				ctx.app.capabilities.handle_received_ping(ctx.result.value.result.ping_id);
			} else {
				ctx.app.capabilities.handle_ping_error(ctx.jsonrpc_message.id, ctx.result.message);
			}
		},
	},

	load_session: {
		send_request: () => {
			console.log('Loading session...');
		},
		receive_response: (ctx) => {
			console.log('Session loaded', ctx);
			if ('todo') {
				ctx.app.receive_session(ctx.result.value.result.data);
			} else {
				console.error('Error loading session', ctx);
			}
		},
	},

	submit_completion: {
		send_request: (ctx) => {
			console.log('Sending prompt', ctx.params.completion_request.prompt);
		},
		receive_response: (ctx) => {
			console.log('Received completion', ctx.params.completion_request, ctx.result);
			if ('todo') {
				return ctx.result.value.result; // acts as a method call, no side effects here
			} else {
				console.error('Error with completion', ctx);
			}
		},
	},

	update_diskfile: {
		send_request: (ctx) => {
			console.log('Updating file', ctx.params.path);
		},
		receive_response: noop,
	},

	delete_diskfile: {
		send_request: (ctx) => {
			console.log('Deleting file', ctx.params.path);
		},
		receive_response: noop,
	},

	create_directory: {
		send_request: (ctx) => {
			console.log('Creating directory', ctx.params.path);
		},
		receive_response: (ctx) => {
			console.log('Created directory', ctx);
		},
	},

	filer_change: {
		receive: (ctx) => {
			console.log('File changed', ctx.params.change, ctx.result);
			ctx.app.diskfiles.handle_change(ctx.params);
		},
	},

	toggle_main_menu: {
		execute: (ctx) => {
			console.log('Toggling main menu', ctx.params);
			return ctx.app.ui.toggle_main_menu(ctx.params);
		},
	},
};
