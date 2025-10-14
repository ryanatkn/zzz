import {Serializable_Disknode} from '$lib/diskfile_types.js';
import type {Backend_Action_Handlers} from '$lib/server/backend_action_types.js';
import type {Action_Outputs} from '$lib/action_collections.js';
import {jsonrpc_errors, Thrown_Jsonrpc_Error} from '$lib/jsonrpc_errors.js';
import {to_serializable_disknode} from '$lib/diskfile_helpers.js';
import {UNKNOWN_ERROR_MESSAGE} from '$lib/constants.js';
import type {Completion_Options, Completion_Handler_Options} from '$lib/server/backend_provider.js';
import {save_completion_response_to_disk} from '$lib/server/helpers.js';
import type {
	Ollama_List_Response,
	Ollama_Ps_Response,
	Ollama_Show_Response,
} from '$lib/ollama_helpers.js';
import {update_env_variable} from '$lib/server/env_file_helpers.js';

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

	session_load: {
		receive_request: async ({backend}) => {
			// TODO change so this only returns metadata, not file contents
			// Access filers through server and collect all files
			const files_array: Array<Serializable_Disknode> = [];

			// Iterate through all filers and collect their files
			for (const filer of backend.filers.values()) {
				for (const file of filer.filer.files.values()) {
					files_array.push(to_serializable_disknode(file, backend.zzz_cache_dir)); // TODO dir is a hack
				}
			}

			// Get provider status in parallel (reload=true for initial session load)
			const provider_status = await Promise.all(backend.providers.map((p) => p.load_status()));

			return {
				data: {
					files: files_array,
					zzz_cache_dir: backend.zzz_cache_dir,
					provider_status,
				},
			};
		},
	},

	completion_create: {
		receive_request: async ({backend, data: {input}}) => {
			const {prompt, provider_name, model, completion_messages} = input.completion_request;
			const progress_token = input._meta?.progressToken;

			console.log(
				'[backend_action_handlers.completion_create.receive_request] progress_token:',
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
				`[backend_action_handlers.completion_create.receive_request] prompting ${provider_name}:`,
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

			let result: Action_Outputs['completion_create'];

			try {
				result = await handler(handler_options);
			} catch (error) {
				// Let our own errors bubble through, wrap provider client errors
				if (error instanceof Thrown_Jsonrpc_Error) {
					throw error;
				}
				console.error(
					`[backend_action_handlers.completion_create.receive_request] AI provider error:`,
					error,
				);
				// TODO SECURITY this may leak details
				// Extract meaningful error message from provider SDK errors
				const error_message = error instanceof Error ? error.message : 'AI provider error';
				throw jsonrpc_errors.ai_provider_error(provider_name, error_message);
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
				`[backend_action_handlers.completion_create.receive_request] got ${provider_name} message`,
				result.completion_response.data,
			);

			return result;
		},
	},

	diskfile_update: {
		receive_request: async ({backend, data: {input, request}}) => {
			console.log(`[backend_action_handlers.diskfile_update.receive_request] message`, request);
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

	diskfile_delete: {
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

	directory_create: {
		receive_request: async ({data: {input}, backend}) => {
			const {path} = input;

			try {
				// Use the server's scoped_fs instance to create the directory
				await backend.scoped_fs.mkdir(path, {recursive: true});
				return null;
			} catch (error) {
				console.error(
					`[backend_action_handlers.directory_create.receive_request] error creating directory ${path}:`,
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
		receive_request: async ({backend}) => {
			console.log('[backend_action_handlers.ollama_list.receive_request] listing models');

			try {
				const response = (await backend
					.lookup_provider('ollama')
					.get_client()
					.list()) as unknown as Ollama_List_Response;
				console.log(
					`[backend_action_handlers.ollama_list.receive_request] found ${response.models.length} models`,
				);
				return response;
			} catch (error) {
				// Let our own errors bubble through, wrap external/client errors
				if (error instanceof Thrown_Jsonrpc_Error) {
					throw error;
				}
				console.error('[backend_action_handlers.ollama_list.receive_request] failed:', error);
				throw jsonrpc_errors.internal_error('failed to list models');
			}
		},
	},

	ollama_ps: {
		receive_request: async ({backend}) => {
			console.log('[backend_action_handlers.ollama_ps.receive_request] getting running models');

			try {
				const response = (await backend
					.lookup_provider('ollama')
					.get_client()
					.ps()) as unknown as Ollama_Ps_Response;
				console.log(
					`[backend_action_handlers.ollama_ps.receive_request] found ${response.models.length} running models`,
				);
				return response;
			} catch (error) {
				// Let our own errors bubble through, wrap external/client errors
				if (error instanceof Thrown_Jsonrpc_Error) {
					throw error;
				}
				console.error('[backend_action_handlers.ollama_ps.receive_request] failed:', error);
				throw jsonrpc_errors.internal_error('failed to get running models');
			}
		},
	},

	ollama_show: {
		receive_request: async ({backend, data: {input}}) => {
			console.log(`[backend_action_handlers.ollama_show.receive_request] showing: ${input.model}`);

			try {
				const response = (await backend
					.lookup_provider('ollama')
					.get_client()
					.show(input)) as unknown as Ollama_Show_Response;
				console.log(
					`[backend_action_handlers.ollama_show.receive_request] success for: ${input.model}`,
				);
				return response;
			} catch (error) {
				// Let our own errors bubble through, wrap external/client errors
				if (error instanceof Thrown_Jsonrpc_Error) {
					throw error;
				}
				console.error(
					`[backend_action_handlers.ollama_show.receive_request] failed for ${input.model}:`,
					error,
				);
				throw jsonrpc_errors.internal_error('failed to show model');
			}
		},
	},

	ollama_pull: {
		receive_request: async ({backend, data: {input}}) => {
			console.log(`[backend_action_handlers.ollama_pull.receive_request] pulling: ${input.model}`);
			const {_meta, ...params} = input;
			try {
				const response = await backend
					.lookup_provider('ollama')
					.get_client()
					.pull({...params, stream: true});

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
				// Let our own errors bubble through, wrap external/client errors
				if (error instanceof Thrown_Jsonrpc_Error) {
					throw error;
				}
				console.error(
					`[backend_action_handlers.ollama_pull.receive_request] failed for ${input.model}:`,
					error,
				);
				throw jsonrpc_errors.internal_error('failed to pull model');
			}
		},
	},

	ollama_delete: {
		receive_request: async ({backend, data: {input}}) => {
			console.log(
				`[backend_action_handlers.ollama_delete.receive_request] deleting: ${input.model}`,
			);

			try {
				await backend.lookup_provider('ollama').get_client().delete(input);
				console.log(
					`[backend_action_handlers.ollama_delete.receive_request] success for: ${input.model}`,
				);
				return undefined;
			} catch (error) {
				// Let our own errors bubble through, wrap external/client errors
				if (error instanceof Thrown_Jsonrpc_Error) {
					throw error;
				}
				console.error(
					`[backend_action_handlers.ollama_delete.receive_request] failed for ${input.model}:`,
					error,
				);
				throw jsonrpc_errors.internal_error('failed to delete model');
			}
		},
	},

	ollama_copy: {
		receive_request: async ({backend, data: {input}}) => {
			const {source, destination} = input;
			console.log(
				`[backend_action_handlers.ollama_copy.receive_request] copying: ${source} --> ${destination}`,
			);

			try {
				await backend.lookup_provider('ollama').get_client().copy(input);
				console.log(
					`[backend_action_handlers.ollama_copy.receive_request] success: ${source} --> ${destination}`,
				);
				return undefined;
			} catch (error) {
				// Let our own errors bubble through, wrap external/client errors
				if (error instanceof Thrown_Jsonrpc_Error) {
					throw error;
				}
				console.error(
					`[backend_action_handlers.ollama_copy.receive_request] failed for ${source} --> ${destination}:`,
					error,
				);
				throw jsonrpc_errors.internal_error('failed to copy model');
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
				const response = await backend
					.lookup_provider('ollama')
					.get_client()
					.create({...params, stream: true});

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
				// Let our own errors bubble through, wrap external/client errors
				if (error instanceof Thrown_Jsonrpc_Error) {
					throw error;
				}
				console.error(
					`[backend_action_handlers.ollama_create.receive_request] failed for ${input.model}:`,
					error,
				);
				throw jsonrpc_errors.internal_error('failed to create model');
			}
		},
	},

	ollama_unload: {
		receive_request: async ({backend, data: {input}}) => {
			console.log(
				`[backend_action_handlers.ollama_unload.receive_request] unloading: ${input.model}`,
			);

			try {
				await backend
					.lookup_provider('ollama')
					.get_client()
					.generate({model: input.model, prompt: '', keep_alive: 0});
				console.log(
					`[backend_action_handlers.ollama_unload.receive_request] success for: ${input.model}`,
				);
				return undefined;
			} catch (error) {
				// Let our own errors bubble through, wrap external/client errors
				if (error instanceof Thrown_Jsonrpc_Error) {
					throw error;
				}
				console.error(
					`[backend_action_handlers.ollama_unload.receive_request] failed for ${input.model}:`,
					error,
				);
				throw jsonrpc_errors.internal_error('failed to unload model');
			}
		},
	},

	provider_load_status: {
		receive_request: async ({backend, data: {input}}) => {
			const {provider_name, reload} = input;
			console.log(
				`[backend_action_handlers.provider_load_status.receive_request] loading ${provider_name} status (reload=${reload ?? true})`,
			);

			const provider = backend.lookup_provider(provider_name);
			const status = await provider.load_status(reload);

			console.log(
				`[backend_action_handlers.provider_load_status.receive_request] ${provider_name} status:`,
				status,
			);

			return {status};
		},
	},

	provider_update_api_key: {
		receive_request: async ({backend, data: {input}}) => {
			const {provider_name, api_key} = input;
			console.log(
				`[backend_action_handlers.provider_update_api_key.receive_request] updating ${provider_name} API key`,
			);

			// Only allow API providers, not Ollama
			if (provider_name === 'ollama') {
				throw jsonrpc_errors.invalid_params('Ollama does not require an API key');
			}

			// Map provider name to environment variable name
			const env_var_map: Record<string, string> = {
				claude: 'SECRET_ANTHROPIC_API_KEY',
				chatgpt: 'SECRET_OPENAI_API_KEY',
				gemini: 'SECRET_GOOGLE_API_KEY',
			};

			const env_var_name = env_var_map[provider_name];
			if (!env_var_name) {
				throw jsonrpc_errors.invalid_params(`Unknown provider: ${provider_name}`);
			}

			try {
				// 1. Update .env file (persistence)
				await update_env_variable(env_var_name, api_key);

				// 2. Update process.env (runtime)
				process.env[env_var_name] = api_key;

				// 3. Update provider client (explicit API)
				const provider = backend.lookup_provider(provider_name);
				provider.set_api_key(api_key);

				// 4. Load fresh status after key update
				const status = await provider.load_status(true);

				console.log(
					`[backend_action_handlers.provider_update_api_key.receive_request] successfully updated ${provider_name} API key`,
				);

				return {status};
			} catch (error) {
				console.error(
					`[backend_action_handlers.provider_update_api_key.receive_request] failed for ${provider_name}:`,
					error,
				);
				throw jsonrpc_errors.internal_error(
					`Failed to update API key: ${error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE}`,
				);
			}
		},
	},
};
