import {Serializable_Source_File} from '$lib/diskfile_types.js';
import type {Backend_Action_Handlers} from '$lib/server/backend_action_types.js';
import type {Action_Outputs} from '$lib/action_collections.js';
import {jsonrpc_errors} from '$lib/jsonrpc_errors.js';
import {to_serializable_source_file} from '$lib/diskfile_helpers.js';
import {UNKNOWN_ERROR_MESSAGE} from '$lib/constants.js';
import {
	type Completion_Options,
	type Completion_Handler_Options,
	get_completion_handler,
	save_completion_response_to_disk,
} from '$lib/server/handle_create_completion.js';

// TODO refactor to a plugin architecture

// TODO API usage is roughed in, very hacky just to get things working -- needs a lot of work like not hardcoding `role` below

/**
 * Handle client messages and produce appropriate server responses.
 * Each returns a value or throws a `Thrown_Jsonrpc_Error`.
 * Organized by method and phase for symmetric handling.
 */
export const backend_action_handlers: Backend_Action_Handlers = {
	ping: {
		receive_request: ({data: {request}}) => {
			console.log(`ping receive_request message`, request);
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
		receive_request: async (action_event) => {
			const {
				backend,
				data: {input},
			} = action_event;
			const {
				completion_request: {prompt, provider_name, model, completion_messages},
				_meta,
			} = input;
			const progress_token = _meta?.progressToken;

			console.log(
				'[backend_action_handlers.create_completion] progress_token:',
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

			console.log(`prompting ${provider_name}:`, prompt.substring(0, 100));

			const handler_options: Completion_Handler_Options = {
				model,
				completion_options,
				completion_messages,
				prompt,
				progress_token,
				backend,
			};

			let result: Action_Outputs['create_completion'];

			try {
				const handler = get_completion_handler(provider_name, !!progress_token);
				result = await handler(handler_options);
			} catch (error) {
				console.error(`AI provider error:`, error);
				throw jsonrpc_errors.ai_provider_error(
					provider_name,
					error instanceof Error ? error.message : 'Unknown AI provider error',
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

			console.log(`got ${provider_name} message`, result.completion_response.data);

			return result;
		},
	},

	update_diskfile: {
		receive_request: async ({backend, data: {input, request}}) => {
			console.log(`message`, request);
			const {path, content} = input;

			try {
				// Use the server's scoped_fs instance to write the file
				await backend.scoped_fs.write_file(path, content);
				return null;
			} catch (error) {
				console.error(`Error writing file ${path}:`, error);
				throw jsonrpc_errors.internal_error(
					`Failed to write file: ${error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE}`,
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
				console.error(`Error deleting file ${path}:`, error);
				throw jsonrpc_errors.internal_error(
					`Failed to delete file: ${error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE}`,
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
				console.error(`Error creating directory ${path}:`, error);
				throw jsonrpc_errors.internal_error(
					`Failed to create directory: ${error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE}`,
				);
			}
		},
	},

	// TODO @api think about logging, validation, or other processing
	filer_change: {
		send: ({data: {input}}) => {
			console.log('Sending filer_change notification', input.source_file.id, input.change);
		},
	},

	completion_progress: {
		send: ({data: {input}}) => {
			console.log(
				'Sending completion_progress notification',
				input._meta?.progressToken,
				input.chunk,
			);
		},
	},
};
