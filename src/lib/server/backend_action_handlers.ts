import {Unreachable_Error} from '@ryanatkn/belt/error.js';
import Anthropic from '@anthropic-ai/sdk';
import OpenAI from 'openai';
import ollama from 'ollama';
import {GoogleGenerativeAI} from '@google/generative-ai';
import {
	SECRET_ANTHROPIC_API_KEY,
	SECRET_GOOGLE_API_KEY,
	SECRET_OPENAI_API_KEY,
} from '$env/static/private';
import {dirname, join} from 'node:path';
import {format_file} from '@ryanatkn/gro/format_file.js';

import {Serializable_Source_File} from '$lib/diskfile_types.js';
import {
	format_ollama_messages,
	format_claude_messages,
	format_openai_messages,
	format_gemini_messages,
} from '$lib/server/ai_provider_utils.js';
import {to_completion_result} from '$lib/response_helpers.js';
import {Scoped_Fs} from '$lib/server/scoped_fs.js';
import type {Backend_Action_Handlers} from '$lib/server/backend_action_types.js';
import type {Action_Inputs, Action_Outputs} from '$lib/action_collections.js';
import {jsonrpc_errors} from '$lib/jsonrpc_errors.js';
import {to_serializable_source_file} from '$lib/diskfile_helpers.js';
import {UNKNOWN_ERROR_MESSAGE} from '$lib/constants.js';

// TODO refactor to a plugin architecture

// AI provider clients
const anthropic = new Anthropic({apiKey: SECRET_ANTHROPIC_API_KEY});
const openai = new OpenAI({apiKey: SECRET_OPENAI_API_KEY});
const google = new GoogleGenerativeAI(SECRET_GOOGLE_API_KEY);

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

	submit_completion: {
		receive_request: async ({backend, data: {input, request}}) => {
			const {prompt, provider_name, model, completion_messages} = input.completion_request;
			// TODO probably refactor so each handler is independent, and destructure all params so we can see what's unused
			const {
				// bots,
				frequency_penalty,
				// models,
				output_token_max,
				presence_penalty,
				// providers,
				seed,
				stop_sequences,
				system_message,
				temperature,
				top_k,
				top_p,
			} = backend.config;

			let result: Action_Outputs['submit_completion'];

			console.log(`texting ${provider_name}:`, prompt.substring(0, 100));

			try {
				switch (provider_name) {
					case 'ollama': {
						// TODO BLOCK is this what we want to do? or error? needs to stream progress if kept
						const listed = await ollama.list();
						if (!listed.models.some((m) => m.name === model)) {
							await ollama.pull({model}); // TODO handle stream
						}
						const api_response = await ollama.chat({
							model,
							// TODO
							// tools,
							options: {
								temperature,
								seed,
								num_predict: output_token_max,
								top_k,
								top_p,
								frequency_penalty,
								presence_penalty,
								stop: stop_sequences,
							},
							messages: format_ollama_messages(system_message, completion_messages, prompt),
						});
						console.log(`ollama api_response`, api_response);
						result = to_completion_result(request.id, provider_name, model, api_response);
						break;
					}

					case 'claude': {
						const api_response = await anthropic.messages.create({
							model,
							max_tokens: output_token_max,
							temperature,
							top_k,
							top_p,
							stop_sequences,
							system: system_message,
							messages: format_claude_messages(completion_messages, prompt),
						});
						console.log(`claude api_response`, api_response);
						result = to_completion_result(request.id, provider_name, model, api_response);
						break;
					}

					case 'chatgpt': {
						const api_response = await openai.chat.completions.create({
							model,
							max_completion_tokens: output_token_max,
							temperature: model === 'o1-mini' ? undefined : temperature,
							seed,
							top_p,
							frequency_penalty,
							presence_penalty,
							stop: stop_sequences,
							messages: format_openai_messages(system_message, completion_messages, prompt, model),
						});
						console.log(`openai api_response`, api_response);
						result = to_completion_result(request.id, provider_name, model, api_response);
						break;
					}

					case 'gemini': {
						// TODO cache this by model?
						const google_model = google.getGenerativeModel({
							model,
							systemInstruction: system_message,
							// TODO
							// tools,
							// toolConfig
							generationConfig: {
								maxOutputTokens: output_token_max,
								temperature,
								topK: top_k,
								topP: top_p,
								frequencyPenalty: frequency_penalty,
								presencePenalty: presence_penalty,
								stopSequences: stop_sequences,
							},
						});

						const content = format_gemini_messages(completion_messages, prompt);
						const api_response = await google_model.generateContent(content);
						console.log(`gemini api_response`, api_response);
						result = to_completion_result(request.id, provider_name, model, api_response);
						break;
					}

					default:
						throw new Unreachable_Error(provider_name);
				}
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
};

// TODO @db refactor
const save_completion_response_to_disk = async (
	input: Action_Inputs['submit_completion'],
	output: Action_Outputs['submit_completion'],
	dir: string,
	scoped_fs: Scoped_Fs,
): Promise<void> => {
	// includes `Date.now()` for sorting purposes
	const filename = `${input.completion_request.provider_name}__${Date.now()}__${input.completion_request.model}__${input.completion_request.request_id}.json`; // TODO include model data in these

	const path = join(dir, filename);

	const json = {input, output};

	await write_json(path, json, scoped_fs);
};
// TODO @db refactor
const write_json = async (path: string, json: unknown, scoped_fs: Scoped_Fs): Promise<void> => {
	// Check if directory exists and create it if needed
	if (!(await scoped_fs.exists(path))) {
		await scoped_fs.mkdir(dirname(path), {recursive: true});
	}

	const formatted = await format_file(JSON.stringify(json), {parser: 'json'});

	// Use Scoped_Fs for writing the file
	console.log('writing json', path, formatted.length);
	await scoped_fs.write_file(path, formatted);
};
