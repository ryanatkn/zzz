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
				ctx.app.capabilities.handle_received_ping(ctx.output.value.result.ping_id);
			} else {
				ctx.app.capabilities.handle_ping_error(ctx.jsonrpc_message.id, ctx.output.message);
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
				ctx.app.receive_session(ctx.output.value.result.data);
			} else {
				console.error('Error loading session', ctx);
			}
		},
	},

	submit_completion: {
		send_request: (ctx) => {
			console.log('Sending prompt', ctx.input.completion_request.prompt);
		},
		receive_response: (ctx) => {
			console.log('Received completion', ctx.input.completion_request, ctx.output);
			if ('todo') {
				return ctx.output.value.result; // acts as a method call, no side effects here
			} else {
				console.error('Error with completion', ctx);
			}
		},
	},

	update_diskfile: {
		send_request: (ctx) => {
			console.log('Updating file', ctx.input.path);
		},
		receive_response: noop,
	},

	delete_diskfile: {
		send_request: (ctx) => {
			console.log('Deleting file', ctx.input.path);
		},
		receive_response: noop,
	},

	create_directory: {
		send_request: (ctx) => {
			console.log('Creating directory', ctx.input.path);
		},
		receive_response: (ctx) => {
			console.log('Created directory', ctx);
		},
	},

	filer_change: {
		receive: (ctx) => {
			console.log('File changed', ctx.input.change, ctx.output);
			ctx.app.diskfiles.handle_change(ctx.input);
		},
	},

	toggle_main_menu: {
		execute: (ctx) => {
			console.log('Toggling main menu', ctx.input);
			return ctx.app.ui.toggle_main_menu(ctx.input);
		},
	},
};
