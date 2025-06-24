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
			console.log('[frontend_action_handlers] Loading session...');
		},
		receive_response: ({app, data: {output, response}}) => {
			console.log('[frontend_action_handlers] Session loaded:', response);

			app.receive_session(output.data);
		},
	},

	submit_completion: {
		send_request: ({data: {input}}) => {
			console.log('[frontend_action_handlers] Sending prompt:', input.completion_request.prompt);
		},
		receive_response: ({data: {input, output}}) => {
			console.log(
				'[frontend_action_handlers] Received completion:',
				input.completion_request,
				output,
			);
		},
	},

	update_diskfile: {
		send_request: ({data: {input}}) => {
			console.log('[frontend_action_handlers] Updating file:', input.path);
		},
		receive_response: ({data: {input, output}}) => {
			console.log('[frontend_action_handlers] Updated file:', input.path, output);
		},
	},

	delete_diskfile: {
		send_request: ({data: {input}}) => {
			console.log('[frontend_action_handlers] Deleting file:', input.path);
		},
		receive_response: ({data: {input}}) => {
			console.log('[frontend_action_handlers] Deleted file:', input.path);
		},
	},

	create_directory: {
		send_request: ({data: {input}}) => {
			console.log('[frontend_action_handlers] Creating directory:', input.path);
		},
		receive_response: (ctx) => {
			console.log('[frontend_action_handlers] Created directory:', ctx);
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
