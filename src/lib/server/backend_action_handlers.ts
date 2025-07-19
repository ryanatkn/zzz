import ollama from 'ollama';

import {Serializable_Source_File} from '$lib/diskfile_types.js';
import type {Backend_Action_Handlers} from '$lib/server/backend_action_types.js';
import type {Action_Outputs} from '$lib/action_collections.js';
import {jsonrpc_errors} from '$lib/jsonrpc_errors.js';
import {to_serializable_source_file} from '$lib/diskfile_helpers.js';
import {UNKNOWN_ERROR_MESSAGE} from '$lib/constants.js';
import type {Completion_Options, Completion_Handler_Options} from '$lib/server/backend_provider.js';
import {save_completion_response_to_disk} from '$lib/server/helpers.js';
import type {
	Ollama_List_Response,
	Ollama_Ps_Response,
	Ollama_Show_Response,
} from '$lib/ollama_helpers.js';

// TODO refactor to a plugin architecture

// TODO API usage is roughed in, very hacky just to get things working -- needs a lot of work
// like not hardcoding `role` below

// TODO proper logging

/**
 * Handle client messages and produce appropriate server responses.
 * Each returns a value or throws a `Thrown_Jsonrpc_Error`.
 * Organized by method and phase for symmetric handling.
 */
export const backend_action_handlers: Backend_Action_Handlers = {
	ping: {
		receive_request: ({data: {request}}) => {
			console.log(
				`[backend_action_handlers.ping.receive_request] ping receive_request message`,
				request,
			);
			return {
				ping_id: request.id,
			};
		},
	},

	load_session: {
		receive_request: ({backend}) => {
			// TODO change so this only returns metadata, not file contents
			// Access filers through server and collect all files
			const files_array: Array<Serializable_Source_File> = [];

			// Iterate through all filers and collect their files
			for (const filer of backend.filers.values()) {
				for (const file of filer.filer.files.values()) {
					files_array.push(to_serializable_source_file(file, backend.zzz_cache_dir)); // TODO dir is a hack
				}
			}

			return {
				data: {
					files: files_array,
					zzz_dir: backend.zzz_dir,
					zzz_cache_dir: backend.zzz_cache_dir,
				},
			};
		},
	},

	create_completion: {
		receive_request: async ({backend, data: {input}}) => {
			const {prompt, provider_name, model, completion_messages} = input.completion_request;
			const progress_token = input._meta?.progressToken;

			console.log(
				'[backend_action_handlers.create_completion.receive_request] progress_token:',
				progress_token,
				'completion_request:',
				input.completion_request,
			);

			const {
				frequency_penalty,
				output_token_max,
				presence_penalty,
				seed,
				stop_sequences,
				system_message,
				temperature,
				top_k,
				top_p,
			} = backend.config;

			const completion_options: Completion_Options = {
				frequency_penalty,
				output_token_max,
				presence_penalty,
				seed,
				stop_sequences,
				system_message,
				temperature,
				top_k,
				top_p,
			};

			console.log(
				`[backend_action_handlers.create_completion.receive_request] prompting ${provider_name}:`,
				prompt.substring(0, 100),
			);

			const handler_options: Completion_Handler_Options = {
				model,
				completion_options,
				completion_messages,
				prompt,
				progress_token,
			};

			const provider = backend.lookup_provider(provider_name); // TODO refactor probably

			const handler = provider.get_handler(!!progress_token);

			let result: Action_Outputs['create_completion'];

			try {
				result = await handler(handler_options);
			} catch (error) {
				console.error(
					`[backend_action_handlers.create_completion.receive_request] AI provider error:`,
					error,
				);
				throw jsonrpc_errors.ai_provider_error(
					provider_name,
					error instanceof Error ? error.message : 'unknown AI provider error',
					{error},
				);
			}

			// TODO @db temporary, do better action tracking
			// We don't need to wait for this to finish
			void save_completion_response_to_disk(
				input,
				result,
				backend.zzz_cache_dir,
				backend.scoped_fs,
			);

			console.log(
				`[backend_action_handlers.create_completion.receive_request] got ${provider_name} message`,
				result.completion_response.data,
			);

			return result;
		},
	},

	update_diskfile: {
		receive_request: async ({backend, data: {input, request}}) => {
			console.log(`[backend_action_handlers.update_diskfile.receive_request] message`, request);
			const {path, content} = input;

			// TODO this clobbers existing files even if that wasn't the intent since there's no `create` action
			try {
				// Use the server's scoped_fs instance to write the file
				await backend.scoped_fs.write_file(path, content);
				return null;
			} catch (error) {
				console.error(`error writing file ${path}:`, error);
				throw jsonrpc_errors.internal_error(
					`failed to write file: ${error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE}`,
				);
			}
		},
	},

	delete_diskfile: {
		receive_request: async ({backend, data: {input}}) => {
			const {path} = input;

			try {
				// Use the server's scoped_fs instance to delete the file
				await backend.scoped_fs.rm(path);
				return null;
			} catch (error) {
				console.error(
					`[backend_action_handlers.delete_diskfile.receive_request] error deleting file ${path}:`,
					error,
				);
				throw jsonrpc_errors.internal_error(
					`failed to delete file: ${error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE}`,
				);
			}
		},
	},

	create_directory: {
		receive_request: async ({data: {input}, backend}) => {
			const {path} = input;

			try {
				// Use the server's scoped_fs instance to create the directory
				await backend.scoped_fs.mkdir(path, {recursive: true});
				return null;
			} catch (error) {
				console.error(
					`[backend_action_handlers.create_directory.receive_request] error creating directory ${path}:`,
					error,
				);
				throw jsonrpc_errors.internal_error(
					`failed to create directory: ${error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE}`,
				);
			}
		},
	},

	// these work but are too noisy right now, maybe at a debug level?

	// TODO @api think about logging, validation, or other processing
	// filer_change: {
	// 	send: ({data: {input}}) => {
	// 		console.log(
	// 			'[backend_action_handlers.filer_change.send] sending filer_change notification',
	// 			input,
	// 		);
	// 	},
	// },

	// completion_progress: {
	// 	send: ({data: {input}}) => {
	// 		console.log(
	// 			'[backend_action_handlers.completion_progress.send] sending completion_progress notification',
	// 			input,
	// 		);
	// 	},
	// },

	// ollama_progress: {
	// 	send: ({data: {input}}) => {
	// 		console.log(
	// 			'[backend_action_handlers.ollama_progress.send] sending ollama_progress notification',
	// 			input,
	// 		);
	// 	},
	// },

	// Ollama action handlers
	ollama_list: {
		receive_request: async () => {
			console.log('[backend_action_handlers.ollama_list.receive_request] listing models');

			try {
				const response = (await ollama.list()) as unknown as Ollama_List_Response;
				console.log(
					`[backend_action_handlers.ollama_list.receive_request] found ${response.models.length} models`,
				);
				return response;
			} catch (error) {
				console.error('[backend_action_handlers.ollama_list.receive_request] failed:', error);
				return null;
			}
		},
	},

	ollama_ps: {
		receive_request: async () => {
			console.log('[backend_action_handlers.ollama_ps.receive_request] getting running models');

			try {
				const response = (await ollama.ps()) as unknown as Ollama_Ps_Response;
				console.log(
					`[backend_action_handlers.ollama_ps.receive_request] found ${response.models.length} running 
  models`,
				);
				return response;
			} catch (error) {
				console.error('[backend_action_handlers.ollama_ps.receive_request] failed:', error);
				return null;
			}
		},
	},

	ollama_show: {
		receive_request: async ({data: {input}}) => {
			console.log(`[backend_action_handlers.ollama_show.receive_request] showing: ${input.model}`);

			try {
				const response = (await ollama.show(input)) as unknown as Ollama_Show_Response;
				console.log(
					`[backend_action_handlers.ollama_show.receive_request] success for: ${input.model}`,
				);
				return response;
			} catch (error) {
				console.error(
					`[backend_action_handlers.ollama_show.receive_request] failed for ${input.model}:`,
					error,
				);
				return null;
			}
		},
	},

	ollama_pull: {
		receive_request: async ({backend, data: {input}}) => {
			console.log(`[backend_action_handlers.ollama_pull.receive_request] pulling: ${input.model}`);
			const {_meta, ...params} = input;
			throw jsonrpc_errors.internal_error(`idk bad things`);
			try {
				const response = await ollama.pull({...params, stream: true});

				for await (const progress of response) {
					// console.log(`[backend_action_handlers.ollama_pull.receive_request] progress`, progress);

					await backend.api.ollama_progress({
						status: progress.status,
						digest: progress.digest,
						total: progress.total,
						completed: progress.completed,
						_meta: {progressToken: _meta?.progressToken},
					});
				}

				console.log(`[backend_action_handlers.ollama_pull.receive_request] completed`);
				return undefined;
			} catch (error) {
				console.error(
					`[backend_action_handlers.ollama_pull.receive_request] failed for ${input.model}:`,
					error,
				);
				throw jsonrpc_errors.internal_error(
					`failed to pull model: ${error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE}`,
				);
			}
		},
	},

	ollama_delete: {
		receive_request: async ({data: {input}}) => {
			console.log(
				`[backend_action_handlers.ollama_delete.receive_request] deleting: ${input.model}`,
			);

			try {
				await ollama.delete(input);
				console.log(
					`[backend_action_handlers.ollama_delete.receive_request] success for: ${input.model}`,
				);
				return undefined;
			} catch (error) {
				console.error(
					`[backend_action_handlers.ollama_delete.receive_request] failed for ${input.model}:`,
					error,
				);
				throw jsonrpc_errors.internal_error(
					`failed to delete model: ${error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE}`,
				);
			}
		},
	},

	ollama_copy: {
		receive_request: async ({data: {input}}) => {
			const {source, destination} = input;
			console.log(
				`[backend_action_handlers.ollama_copy.receive_request] copying: ${source} --> ${destination}`,
			);

			try {
				await ollama.copy(input);
				console.log(
					`[backend_action_handlers.ollama_copy.receive_request] success: ${source} --> ${destination}`,
				);
				return undefined;
			} catch (error) {
				console.error(
					`[backend_action_handlers.ollama_copy.receive_request] failed for ${source} --> ${destination}:`,
					error,
				);
				throw jsonrpc_errors.internal_error(
					`failed to copy model: ${error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE}`,
				);
			}
		},
	},

	ollama_create: {
		receive_request: async ({backend, data: {input}}) => {
			console.log(
				`[backend_action_handlers.ollama_create.receive_request] creating: ${input.model}`,
			);
			const {_meta, ...params} = input;

			try {
				const response = await ollama.create({...params, stream: true});

				for await (const progress of response) {
					// console.log(`[backend_action_handlers.ollama_create.receive_request] progress`, progress);

					await backend.api.ollama_progress({
						status: progress.status,
						digest: progress.digest,
						total: progress.total,
						completed: progress.completed,
						_meta: {progressToken: _meta?.progressToken},
					});
				}

				console.log(
					`[backend_action_handlers.ollama_create.receive_request] success for: ${input.model}`,
				);
				return undefined;
			} catch (error) {
				console.error(
					`[backend_action_handlers.ollama_create.receive_request] failed for ${input.model}:`,
					error,
				);
				throw jsonrpc_errors.internal_error(
					`failed to create model: ${error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE}`,
				);
			}
		},
	},

	ollama_unload: {
		receive_request: async ({data: {input}}) => {
			console.log(
				`[backend_action_handlers.ollama_unload.receive_request] unloading: ${input.model}`,
			);

			try {
				await ollama.generate({model: input.model, prompt: '', keep_alive: 0});
				console.log(
					`[backend_action_handlers.ollama_unload.receive_request] success for: ${input.model}`,
				);
				return undefined;
			} catch (error) {
				console.error(
					`[backend_action_handlers.ollama_unload.receive_request] failed for ${input.model}:`,
					error,
				);
				throw jsonrpc_errors.internal_error(
					`failed to unload model: ${error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE}`,
				);
			}
		},
	},
};
