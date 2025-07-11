import type {Frontend_Action_Handlers} from '$lib/frontend_action_types.js';
import {Strip} from '$lib/strip.svelte.js';
import {to_completion_response_text} from './response_helpers.js';

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
			console.log('[frontend_action_handlers] loading session...');
		},
		receive_response: ({app, data: {output, response}}) => {
			console.log('[frontend_action_handlers] session loaded:', response);

			app.receive_session(output.data);
		},
	},

	create_completion: {
		send_request: (action_event) => {
			const {
				data: {input},
			} = action_event;
			console.log('[frontend_action_handlers] sending prompt:', input.completion_request.prompt);
		},
		receive_response: (action_event) => {
			const {
				app,
				data: {input, output},
			} = action_event;
			console.log(
				'[frontend_action_handlers] received completion:',
				input.completion_request,
				output,
			);

			// TODO hacky
			const progress_token = input._meta?.progressToken;
			if (progress_token) {
				const strip = app.cell_registry.all.get(progress_token);
				if (strip) {
					if (strip instanceof Strip) {
						// TODO hacky, shouldnt need to do this
						// Get the final response text
						const response_text = to_completion_response_text(output.completion_response) || '';

						// Update the assistant strip with the final response content and metadata
						strip.content = response_text;
						strip.response = output.completion_response;
					} else {
						console.error(
							'[frontend_action_handlers] unknown cell type for for completion progress_token:',
							progress_token,
						);
					}
					return;
				}

				console.error(
					'[frontend_action_handlers] no assistant strip found for completion progress_token:',
					progress_token,
				);
			}
		},
	},

	update_diskfile: {
		send_request: ({data: {input}}) => {
			console.log('[frontend_action_handlers] updating file:', input.path);
		},
		receive_response: ({data: {input, output}}) => {
			console.log('[frontend_action_handlers] updated file:', input.path, output);
		},
	},

	delete_diskfile: {
		send_request: ({data: {input}}) => {
			console.log('[frontend_action_handlers] deleting file:', input.path);
		},
		receive_response: ({data: {input}}) => {
			console.log('[frontend_action_handlers] deleted file:', input.path);
		},
	},

	create_directory: {
		send_request: ({data: {input}}) => {
			console.log('[frontend_action_handlers] creating directory:', input.path);
		},
		receive_response: (ctx) => {
			console.log('[frontend_action_handlers] created directory:', ctx);
		},
	},

	filer_change: {
		receive: ({app, data: {input}}) => {
			app.diskfiles.handle_change(input);
		},
	},

	completion_progress: {
		receive: ({app, data: {input}}) => {
			// console.log('[frontend_action_handlers] received completion streaming progress:', input);
			const {chunk} = input;
			const progress_token = input._meta?.progressToken;

			const strip = progress_token && app.cell_registry.all.get(progress_token);

			if (!strip || !(strip instanceof Strip) || !chunk || strip.role !== chunk.message?.role) {
				console.error(
					'[frontend_action_handlers] no matching strip found for progress_token:',
					progress_token,
					'chunk:',
					chunk,
				);
				return;
			}

			strip.content += chunk.message.content;
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
			return await app.ollama.handle_ollama_list();
		},
	},
	ollama_ps: {
		execute: async ({app}) => {
			console.log('[frontend_action_handlers.ollama_ps]');
			return await app.ollama.handle_ollama_ps();
		},
	},
	ollama_show: {
		execute: async ({app, data: {input}}) => {
			console.log('[frontend_action_handlers.ollama_show]', input);
			return await app.ollama.handle_ollama_show(input);
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
