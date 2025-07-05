import type {Frontend_Action_Handlers} from '$lib/frontend_action_types.js';

// TODO stubbing out a lot of these

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

	ollama_list: {
		execute: async ({app}) => {
			console.log('[frontend_action_handlers.ollama_list]');
			return (await app.ollama.handle_ollama_list())!; // TODO BLOCK @many schema type is wrong but `nullable()` doesn't work
		},
	},
	ollama_ps: {
		execute: async ({app}) => {
			console.log('[frontend_action_handlers.ollama_ps]');
			return (await app.ollama.handle_ollama_ps())!; // TODO BLOCK @many schema type is wrong but `nullable()` doesn't work
		},
	},
	ollama_show: {
		execute: async ({app, data: {input}}) => {
			console.log('[frontend_action_handlers.ollama_show]', input);
			return (await app.ollama.handle_ollama_show(input))!; // TODO BLOCK @many schema type is wrong but `nullable()` doesn't work
		},
	},
	ollama_pull: {
		execute: async (action_event) => {
			const {
				app,
				data: {input},
			} = action_event;
			console.log('[frontend_action_handlers.ollama_pull]', input);
			// TODO is this the pattern we want?
			await app.ollama.handle_ollama_pull(input, (progress) => {
				action_event.update_progress(progress);
			});
		},
	},
	ollama_delete: {
		execute: async ({app, data: {input}}) => {
			console.log('[frontend_action_handlers.ollama_delete]', input);
			await app.ollama.handle_ollama_delete(input);
		},
	},
	ollama_copy: {
		execute: async ({app, data: {input}}) => {
			console.log('[frontend_action_handlers.ollama_copy]', input);
			await app.ollama.handle_ollama_copy(input);
		},
	},
	ollama_create: {
		execute: async ({app, data: {input}}) => {
			console.log('[frontend_action_handlers.ollama_create]', input);
			await app.ollama.handle_ollama_create(input);
		},
	},
};
