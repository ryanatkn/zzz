import type {Client_Action_Handlers} from '$lib/client_action_types.js';

// TODO we may also want method-based or middleware-like APIs

/**
 * These map to message types, not action methods.
 */
export const client_action_handlers: Client_Action_Handlers = {
	ping: {
		send_request: ({app, message}) => {
			console.log('Ping request sent');
			app.capabilities.handle_sent_ping(message.id); // TODO BLOCK @api type safety
		},
		receive_response: ({app, output}) => {
			console.log('Ping response received');
			// TODO BLOCK @api @many this handler should be able to assume `output` is defined, see also response_message
			if (!output) {
				console.error('Ping response is missing output');
				return;
			}
			app.capabilities.handle_received_ping(output.ping_id);
			// TODO BLOCK @api how to handle errors? check args or separate handler?
			// app.capabilities.handle_ping_error(jsonrpc_message.id, output.message);
		},
	},

	load_session: {
		send_request: () => {
			console.log('Loading session...');
		},
		receive_response: ({app, output}) => {
			console.log('Session loaded');
			// TODO BLOCK @api @many this handler should be able to assume `output` is defined, see also response_message
			if (!output) {
				console.error('Ping response is missing output');
				return;
			}
			app.receive_session(output.data);
		},
	},

	submit_completion: {
		send_request: ({input}) => {
			console.log('Sending prompt', input.completion_request.prompt);
		},
		receive_response: ({input, output}) => {
			console.log('Received completion', input.completion_request, output);
		},
	},

	update_diskfile: {
		send_request: ({input}) => {
			console.log('Updating file', input.path);
		},
		// receive_response: noop,
	},

	delete_diskfile: {
		send_request: ({input}) => {
			console.log('Deleting file', input.path);
		},
		// receive_response: noop,
	},

	create_directory: {
		send_request: ({input}) => {
			console.log('Creating directory', input.path);
		},
		receive_response: (ctx) => {
			console.log('Created directory', ctx);
		},
	},

	filer_change: {
		receive: ({app, input, output}) => {
			console.log('File changed', input.change, output);
			app.diskfiles.handle_change(input);
		},
	},

	toggle_main_menu: {
		execute: ({app, input}) => {
			console.log('Toggling main menu', input);
			return app.ui.toggle_main_menu(input);
		},
	},
};
