import type {Frontend_Action_Handlers} from '$lib/frontend_action_types.js';
import {Strip} from '$lib/strip.svelte.js';
import {to_completion_response_text} from '$lib/response_helpers.js';

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
		send_request: ({app}) => {
			console.log('[frontend_action_handlers] sending ollama_list request');
			app.ollama.handle_ollama_list_start();
		},
		receive_response: ({app, data: {output}}) => {
			console.log('[frontend_action_handlers] received ollama_list response:', output);
			app.ollama.handle_ollama_list_complete(output);
		},
	},
	ollama_ps: {
		send_request: ({app}) => {
			console.log('[frontend_action_handlers] sending ollama_ps request');
			app.ollama.handle_ollama_ps_start();
		},
		receive_response: ({app, data: {output}}) => {
			console.log('[frontend_action_handlers] received ollama_ps response:', output);
			app.ollama.handle_ollama_ps_complete(output);
		},
	},
	ollama_show: {
		send_request: ({data: {input}}) => {
			console.log('[frontend_action_handlers] sending ollama_show request:', input);
		},
		receive_response: ({app, data: {input, output}}) => {
			console.log('[frontend_action_handlers] received ollama_show response:', input, output);
			app.ollama.handle_ollama_show(input, output);
		},
	},
	ollama_pull: {
		send_request: ({app, data: {input}}) => {
			console.log('[frontend_action_handlers] sending ollama_pull request:', input);
			app.ollama.handle_ollama_pull_start(input);
		},
		receive_response: ({app, data: {input, output}}) => {
			console.log('[frontend_action_handlers] received ollama_pull response:', input, output);
			app.ollama.handle_ollama_pull_complete(input);
		},
	},
	ollama_delete: {
		send_request: ({data: {input}}) => {
			console.log('[frontend_action_handlers] sending ollama_delete request:', input);
		},
		receive_response: async ({app, data: {input}}) => {
			console.log('[frontend_action_handlers] received ollama_delete response:', input);
			await app.ollama.handle_ollama_delete(input);
		},
	},
	ollama_copy: {
		send_request: ({data: {input}}) => {
			console.log('[frontend_action_handlers] sending ollama_copy request:', input);
		},
		receive_response: async ({app, data: {input}}) => {
			console.log('[frontend_action_handlers] received ollama_copy response:', input);
			await app.ollama.handle_ollama_copy(input);
		},
	},
	ollama_create: {
		send_request: ({app, data: {input}}) => {
			console.log('[frontend_action_handlers] sending ollama_create request:', input);
			app.ollama.handle_ollama_create_start(input);
		},
		receive_response: async ({app, data: {input}}) => {
			console.log('[frontend_action_handlers] received ollama_create response:', input);
			await app.ollama.handle_ollama_create_complete(input);
		},
	},

	ollama_progress: {
		receive: ({app, data: {input}}) => {
			// console.log('[frontend_action_handlers] received ollama_progress notification:', input);

			const {_meta, ...progress} = input;
			if (!_meta) {
				console.error('[frontend_action_handlers] ollama_progress missing _meta');
				return;
			}

			// TODO this is hacky, rethink in combination with some other things including the backend,
			// also notice we have a different progress pattern for other actions because the data received is different,
			// but there's probably a cleaner/simpler design

			const progress_token = _meta.progressToken;
			if (!progress_token) {
				console.error('[frontend_action_handlers] ollama_progress missing progress_token');
				return;
			}

			// TODO refactor
			const action = app.actions.items.values.find(
				(a) => (a.action_event_data?.input as any)?._meta?.progressToken === progress_token,
			);
			if (!action) {
				console.error(
					'[frontend_action_handlers] ollama_progress cannot find action for progress_token:',
					progress_token,
				);
				return;
			}
			if (!action.action_event) {
				console.error(
					'[frontend_action_handlers] action does not have action_event reference',
					action,
				);
				return;
			}

			action.action_event.update_progress(progress);
		},
	},
};
