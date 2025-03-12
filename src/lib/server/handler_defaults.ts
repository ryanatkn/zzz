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
import {existsSync, mkdirSync, writeFileSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {format_file} from '@ryanatkn/gro/format_file.js';
import type {Watcher_Change} from '@ryanatkn/gro/watch_dir.js';
import {DEV} from 'esm-env';

import {
	type Message_Client,
	type Message_Completion_Response,
	type Message_Server,
	type Message_Send_Prompt,
} from '$lib/message_types.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Diskfile_Path, Source_File} from '$lib/diskfile_types.js';
import {delete_diskfile_in_scope, write_file_in_scope} from '$lib/server/helpers.js';
import {map_watcher_change_to_diskfile_change} from '$lib/diskfile_helpers.js';
import {
	format_ollama_messages,
	format_claude_messages,
	format_openai_messages,
	format_gemini_messages,
} from '$lib/server/ai_provider_utils.js';
import {create_completion_response_message} from '$lib/response_helpers.js';
import type {Zzz_Server} from '$lib/server/zzz_server.js';

// AI provider clients
const anthropic = new Anthropic({apiKey: SECRET_ANTHROPIC_API_KEY});
const openai = new OpenAI({apiKey: SECRET_OPENAI_API_KEY});
const google = new GoogleGenerativeAI(SECRET_GOOGLE_API_KEY);

/**
 * Handle client messages and produce appropriate server responses
 * A stateless function that uses the zzz_server for access to state and configuration
 */
export const handle_message = async (
	message: Message_Client,
	server: Zzz_Server,
): Promise<Message_Server | null> => {
	console.log(`[handle_message] message`, message.id, message.type);

	switch (message.type) {
		case 'ping': {
			return {
				id: Uuid.parse(undefined),
				type: 'pong',
				ping_id: message.id,
			};
		}
		case 'load_session': {
			// Access filer through server
			const files_record: Record<string, any> = {};

			server.filer.files.forEach((file, id) => {
				const path_id = Diskfile_Path.parse(id);
				files_record[path_id] = {
					...file,
					id: path_id,
					dependents: file.dependents,
					dependencies: file.dependencies,
				};
			});

			return {
				id: Uuid.parse(undefined),
				type: 'loaded_session',
				data: {files: files_record},
			};
		}
		case 'send_prompt': {
			const {prompt, provider_name, model, tape_history} = message.completion_request;
			const config = server.config;

			let response: Message_Completion_Response;

			console.log(`texting ${provider_name}:`, prompt.substring(0, 1000));

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
						messages: format_ollama_messages(config.system_message, tape_history, prompt),
					});
					console.log(`ollama api_response`, api_response);
					response = create_completion_response_message(
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
						messages: format_claude_messages(tape_history, prompt),
					});
					console.log(`claude api_response`, api_response);
					response = create_completion_response_message(
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
						messages: format_openai_messages(config.system_message, tape_history, prompt, model),
					});
					console.log(`openai api_response`, api_response);
					response = create_completion_response_message(
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

					const content = format_gemini_messages(tape_history, prompt);
					const api_response = await google_model.generateContent(content);
					console.log(`gemini api_response`, api_response);
					response = create_completion_response_message(
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

			// don't need to wait for this to finish,
			// the expected file event is now independent of the request
			void save_response(message, response, server.filer.root_dir);

			console.log(`got ${provider_name} message`, response.completion_response.data);

			return response;
		}
		case 'update_diskfile': {
			const {path, contents} = message;
			write_file_in_scope(path, contents, server.filer.root_dir);
			return null;
		}
		case 'delete_diskfile': {
			const {path} = message;
			delete_diskfile_in_scope(path, server.filer.root_dir);
			return null;
		}
		default:
			throw new Unreachable_Error(message);
	}
};

/**
 * Handle file system changes and notify clients
 */
export const handle_filer_change = (
	change: Watcher_Change,
	source_file: Record<string, any>,
	server: Zzz_Server,
): void => {
	const api_change = {
		type: map_watcher_change_to_diskfile_change(change.type),
		path: Diskfile_Path.parse(change.path),
	};

	// Ensure the ID is properly typed
	source_file.id = Diskfile_Path.parse(source_file.id);

	// Declare variable for the source file that will be sent
	let parsed_source_file: Source_File;

	// In development mode, validate strictly
	if (DEV) {
		// Use direct parse to make errors loud and fail fast
		parsed_source_file = Source_File.parse(source_file);
	} else {
		// In production, simply typecast for performance (we control both sides)
		parsed_source_file = source_file as Source_File;
	}

	server.send({
		id: Uuid.parse(undefined),
		type: 'filer_change',
		change: api_change,
		source_file: parsed_source_file,
	});
};

// Helper function to save the response to disk
const save_response = async (
	request: Message_Send_Prompt,
	response: Message_Completion_Response,
	dir: string,
): Promise<void> => {
	// includes `Date.now()` for sorting purposes
	const filename = `${request.completion_request.provider_name}__${Date.now()}__${request.completion_request.model}__${response.id}.json`; // TODO include model data in these

	const path = join(dir, filename);

	const json = {request, response}; // TODO BLOCK type - include the id on each

	await write_json(path, json);
};

const write_json = async (path: string, json: unknown): Promise<void> => {
	const dir = dirname(path);
	if (!existsSync(dir)) {
		mkdirSync(dir, {recursive: true});
	}

	const formatted = await format_file(JSON.stringify(json), {parser: 'json'});

	writeFileSync(path, formatted);
};
