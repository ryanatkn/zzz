// src/lib/server/handler_defaults.ts

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
import {DEV} from 'esm-env';
import type {Source_File} from '@ryanatkn/gro/filer.js';

import {Action_Messages} from '$lib/action_messages.js';
import type {Action_Message_From_Client} from '$lib/action_collections.js';
import {create_uuid, get_datetime_now} from '$lib/zod_helpers.js';
import {Diskfile_Path, Serializable_Source_File} from '$lib/diskfile_types.js';
import {map_watcher_change_to_diskfile_change} from '$lib/diskfile_helpers.js';
import {
	format_ollama_messages,
	format_claude_messages,
	format_openai_messages,
	format_gemini_messages,
} from '$lib/server/ai_provider_utils.js';
import {to_completion_response_params} from '$lib/response_helpers.js';
import type {Filer_Change_Handler, Zzz_Server} from '$lib/server/zzz_server.js';
import {Safe_Fs} from '$lib/server/safe_fs.js';
import type {Action_Message_Params} from '$lib/action_metatypes.js';
import {to_action_message} from '$lib/action_helpers.js';
import {jsonrpc_errors} from '$lib/jsonrpc_errors.js';

// TODO refactor to a plugin architecture

// AI provider clients
const anthropic = new Anthropic({apiKey: SECRET_ANTHROPIC_API_KEY});
const openai = new OpenAI({apiKey: SECRET_OPENAI_API_KEY});
const google = new GoogleGenerativeAI(SECRET_GOOGLE_API_KEY);

/**
 * Handle client messages and produce appropriate server responses.
 * Each returns a value or throws a `Jsonrpc_Error`.
 */
export const handle_message = async (
	message: Action_Message_From_Client,
	server: Zzz_Server,
): Promise<unknown> => {
	console.log(`[handle_message] message`, message.id, message.method);

	// TODO service registration in zzz_server with plugin system
	switch (message.method) {
		case 'ping': {
			return {
				ping_id: message.id,
			};
		}

		case 'load_session': {
			// TODO change so this only returns metadata, not file contents
			// Access filers through server and collect all files
			const files_array: Array<Serializable_Source_File> = [];

			// Iterate through all filers and collect their files
			for (const filer of server.filers.values()) {
				for (const file of filer.filer.files.values()) {
					files_array.push(to_serializable_source_file(file, server.zzz_cache_dir)); // TODO dir is a hack
				}
			}

			return {
				data: {
					files: files_array,
					zzz_dir: server.zzz_dir,
					zzz_cache_dir: server.zzz_cache_dir,
				},
			};
		}

		case 'submit_completion': {
			const {prompt, provider_name, model, completion_messages} = message.params.completion_request;
			const config = server.config;

			let response_params: Action_Message_Params['submit_completion_response'];

			console.log(`texting ${provider_name}:`, prompt.substring(0, 1000));

			try {
				switch (provider_name) {
					case 'ollama': {
						const listed = await ollama.list();
						if (!listed.models.some((m) => m.name === model)) {
							await ollama.pull({model}); // TODO handle stream
						}
						const api_response = await ollama.chat({
							model,
							// TODO
							// tools,
							options: {
								temperature: config.temperature,
								seed: config.seed,
								num_predict: config.output_token_max,
								top_k: config.top_k,
								top_p: config.top_p,
								frequency_penalty: config.frequency_penalty,
								presence_penalty: config.presence_penalty,
								stop: config.stop_sequences,
							},
							messages: format_ollama_messages(config.system_message, completion_messages, prompt),
						});
						console.log(`ollama api_response`, api_response);
						response_params = to_completion_response_params(
							message.id,
							provider_name,
							model,
							api_response,
						);
						break;
					}

					case 'claude': {
						const api_response = await anthropic.messages.create({
							model,
							max_tokens: config.output_token_max,
							temperature: config.temperature,
							top_k: config.top_k,
							top_p: config.top_p,
							stop_sequences: config.stop_sequences,
							system: config.system_message,
							messages: format_claude_messages(completion_messages, prompt),
						});
						console.log(`claude api_response`, api_response);
						response_params = to_completion_response_params(
							message.id,
							provider_name,
							model,
							api_response,
						);
						break;
					}

					case 'chatgpt': {
						const api_response = await openai.chat.completions.create({
							model,
							max_completion_tokens: config.output_token_max,
							temperature: model === 'o1-mini' ? undefined : config.temperature,
							seed: config.seed,
							top_p: config.top_p,
							frequency_penalty: config.frequency_penalty,
							presence_penalty: config.presence_penalty,
							stop: config.stop_sequences,
							messages: format_openai_messages(
								config.system_message,
								completion_messages,
								prompt,
								model,
							),
						});
						console.log(`openai api_response`, api_response);
						response_params = to_completion_response_params(
							message.id,
							provider_name,
							model,
							api_response,
						);
						break;
					}

					case 'gemini': {
						// TODO cache this by model?
						const google_model = google.getGenerativeModel({
							model,
							systemInstruction: config.system_message,
							// TODO
							// tools,
							// toolConfig
							generationConfig: {
								maxOutputTokens: config.output_token_max,
								temperature: config.temperature,
								topK: config.top_k,
								topP: config.top_p,
								frequencyPenalty: config.frequency_penalty,
								presencePenalty: config.presence_penalty,
								stopSequences: config.stop_sequences,
							},
						});

						const content = format_gemini_messages(completion_messages, prompt);
						const api_response = await google_model.generateContent(content);
						console.log(`gemini api_response`, api_response);
						response_params = to_completion_response_params(
							message.id,
							provider_name,
							model,
							api_response,
						);
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

			// TODO this is currently only being created for logging/history purposes, doesn't get sent to client
			const response_message = to_action_message(
				'submit_completion_response',
				response_params,
				message.jsonrpc_message_id,
			);

			// We don't need to wait for this to finish
			void save_response(message, response_message, server.zzz_cache_dir, server.safe_fs);

			console.log(`got ${provider_name} message`, response_params.completion_response.data);

			return response_params;
		}

		case 'update_diskfile': {
			console.log(`message`, message);
			const {
				params: {path, content},
			} = message;

			try {
				// Use the server's safe_fs instance to write the file
				await server.safe_fs.write_file(path, content);
				return null;
			} catch (error) {
				console.error(`Error writing file ${path}:`, error);
				throw jsonrpc_errors.internal_error(
					`Failed to write file: ${error instanceof Error ? error.message : 'Unknown error'}`,
				);
			}
		}

		case 'delete_diskfile': {
			const {
				params: {path},
			} = message;

			try {
				// Use the server's safe_fs instance to delete the file
				await server.safe_fs.rm(path);
				return null;
			} catch (error) {
				console.error(`Error deleting file ${path}:`, error);
				throw jsonrpc_errors.internal_error(
					`Failed to delete file: ${error instanceof Error ? error.message : 'Unknown error'}`,
				);
			}
		}

		case 'create_directory': {
			const {
				params: {path},
			} = message;

			try {
				// Use the server's safe_fs instance to create the directory
				await server.safe_fs.mkdir(path, {recursive: true});
				return null;
			} catch (error) {
				console.error(`Error creating directory ${path}:`, error);
				throw jsonrpc_errors.internal_error(
					`Failed to create directory: ${error instanceof Error ? error.message : 'Unknown error'}`,
				);
			}
		}

		default:
			throw new Unreachable_Error(message);
	}
};

/**
 * Handle file system changes and notify clients.
 */
export const handle_filer_change: Filer_Change_Handler = (
	change,
	source_file,
	server,
	dir,
): void => {
	const api_change = {
		type: map_watcher_change_to_diskfile_change(change.type),
		path: Diskfile_Path.parse(change.path),
	};

	// Declare variable for the source file that will be sent
	const serializable_source_file = to_serializable_source_file(source_file, dir);

	// In development mode, validate strictly and fail loudly.
	// This is less of a need in production because we control both sides,
	// but maybe it should be optional or even required.
	if (DEV) {
		Serializable_Source_File.parse(serializable_source_file);

		// TODO can this be moved to the schema?
		if (!serializable_source_file.id.startsWith(serializable_source_file.source_dir)) {
			throw new Error(
				`Source file ${serializable_source_file.id} does not start with source dir ${serializable_source_file.source_dir}`,
			);
		}
	}

	console.log(`change, source_file.id`, change, source_file.id);

	server.send_action_message({
		id: create_uuid(),
		created: get_datetime_now(),
		type: 'filer_change', // TODO BLOCK @api hacky
		method: 'filer_change',
		jsonrpc_message_id: null,
		params: {
			change: api_change,
			source_file: serializable_source_file,
		},
	});
};

// TODO @db refactor
const save_response = async (
	request: Action_Messages['submit_completion_request'],
	response: Action_Messages['submit_completion_response'],
	dir: string,
	safe_fs: Safe_Fs,
): Promise<void> => {
	// includes `Date.now()` for sorting purposes
	const filename = `${request.params.completion_request.provider_name}__${Date.now()}__${request.params.completion_request.model}__${response.id}.json`; // TODO include model data in these

	const path = join(dir, filename);

	const json = {request, response};

	await write_json(path, json, safe_fs);
};
// TODO @db refactor
const write_json = async (path: string, json: unknown, safe_fs: Safe_Fs): Promise<void> => {
	// Check if directory exists and create it if needed
	if (!(await safe_fs.exists(path))) {
		await safe_fs.mkdir(dirname(path), {recursive: true});
	}

	const formatted = await format_file(JSON.stringify(json), {parser: 'json'});

	// Use Safe_Fs for writing the file
	console.log('writing json', path, formatted.length);
	await safe_fs.write_file(path, formatted);
};

// TODO @many refactor source/disk files with Gro Source_File too
const to_serializable_source_file = (
	source_file: Source_File,
	dir: string,
): Serializable_Source_File => ({
	id: source_file.id as Diskfile_Path,
	source_dir: dir as Diskfile_Path,
	contents: source_file.contents,
	ctime: source_file.ctime,
	mtime: source_file.mtime,
	dependents: Array.from(
		source_file.dependents.entries(),
	) as Serializable_Source_File['dependents'],
	dependencies: Array.from(
		source_file.dependencies.entries(),
	) as Serializable_Source_File['dependencies'],
}); // TODO @many refactor source/disk files with Gro Source_File too
