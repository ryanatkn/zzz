import type {Frontend_Action_Handlers} from '$lib/frontend_action_types.js';

export const frontend_action_handlers: Frontend_Action_Handlers = {
	ping: {
		send_request: ({app, data: {request}}) => {
			app.capabilities.handle_sent_ping(request.id);
		},
		receive_response: ({app, data: {output}}) => {
			app.capabilities.handle_received_ping(output.ping_id);
		},
	},

	load_session: {
		send_request: () => {
			console.log('Loading session...');
		},
		receive_response: ({app, data: {output, response}}) => {
			console.log('Session loaded', response);

			app.receive_session(output.data);
		},
	},

	submit_completion: {
		send_request: ({data: {input}}) => {
			console.log('Sending prompt', input.completion_request.prompt);
		},
		receive_response: ({data: {input, output}}) => {
			console.log('Received completion', input.completion_request, output);
		},
	},

	update_diskfile: {
		send_request: ({data: {input}}) => {
			console.log('Updating file', input.path);
		},
		receive_response: ({data: {input, output}}) => {
			console.log('Updated file', input.path, output);
		},
	},

	delete_diskfile: {
		send_request: ({data: {input}}) => {
			console.log('Deleting file', input.path);
		},
		receive_response: ({data: {input}}) => {
			console.log('Deleted file', input.path);
		},
	},

	create_directory: {
		send_request: ({data: {input}}) => {
			console.log('Creating directory', input.path);
		},
		receive_response: (ctx) => {
			console.log('Created directory', ctx);
		},
	},

	filer_change: {
		receive: ({app, data: {input}}) => {
			app.diskfiles.handle_change(input);
		},
	},

	toggle_main_menu: {
		execute: ({app, data: {input}}) => {
			return {show: app.ui.toggle_main_menu(input?.show)};
		},
	},
};
