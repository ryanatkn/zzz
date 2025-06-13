import type {Frontend_Action_Handlers} from '$lib/frontend_action_types.js';

// TODO we may also want method-based or middleware-like APIs

/**
 * These map to message types, not action methods.
 */
export const frontend_action_handlers: Frontend_Action_Handlers = {
	ping: {
		send_request: ({app, request_message: message}) => {
			console.log('Ping request sent');
			app.capabilities.handle_sent_ping(message.id); // TODO BLOCK @api type safety
		},
		receive_response: ({app, output}) => {
			console.log('Ping response received');

			app.capabilities.handle_received_ping(output.ping_id);
			// TODO BLOCK @api how to handle errors? check args or separate handler?
			// app.capabilities.handle_ping_error(jsonrpc_message.id, output.message);
		},
	},

	load_session: {
		send_request: () => {
			console.log('Loading session...');
		},
		receive_response: ({app, output, response_message}) => {
			console.log('Session loaded', response_message);

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
		receive_response: ({input, output}) => {
			console.log('Updated file', input.path, output);
		},
	},

	delete_diskfile: {
		send_request: ({input}) => {
			console.log('Deleting file', input.path);
		},
		receive_response: ({input}) => {
			console.log('Deleted file', input.path);
		},
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
		execute: ({environment, input}) => {
			console.log('Toggling main menu', input);
			// TODO BLOCK @api was `app` for the client, `environment` is weird?
			return environment.ui.toggle_main_menu(input);
		},
	},
};
