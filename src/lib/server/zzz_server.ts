import {Unreachable_Error} from '@ryanatkn/belt/error.js';
import Anthropic from '@anthropic-ai/sdk';
import OpenAI from 'openai';
import ollama from 'ollama';
import {GoogleGenerativeAI} from '@google/generative-ai';
import {Filer, type Cleanup_Watch} from '@ryanatkn/gro/filer.js';
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
	type Message_Send_Prompt,
	type Message_Server,
} from '$lib/message_types.js';
import {Uuid, Datetime_Now} from '$lib/zod_helpers.js';
import {SYSTEM_MESSAGE_DEFAULT} from '$lib/config.js';
import {delete_diskfile_in_scope, write_file_in_scope} from '$lib/server/helpers.js';
import {Diskfile_Path, Source_File} from '$lib/diskfile_types.js';
import {map_watcher_change_to_diskfile_change} from '$lib/diskfile_helpers.js';
import {
	format_ollama_messages,
	format_claude_messages,
	format_openai_messages,
	format_gemini_messages,
} from '$lib/server/ai_provider_utils.js';
import type {Provider_Name} from '$lib/provider_types.js';

const anthropic = new Anthropic({apiKey: SECRET_ANTHROPIC_API_KEY});
const openai = new OpenAI({apiKey: SECRET_OPENAI_API_KEY});
const google = new GoogleGenerativeAI(SECRET_GOOGLE_API_KEY);

const ZZZ_DIR_DEFAULT = './.zzz';

const OUTPUT_TOKEN_MAX_DEFAULT = 1000; // TODO config
const TEMPERATURE_DEFAULT = 0; // TODO config
const SEED_DEFAULT: number | undefined = undefined; // TODO config
const TOP_K_DEFAULT: number | undefined = undefined; // TODO config
const TOP_P_DEFAULT: number | undefined = undefined; // TODO config
const FREQUENCY_PENALTY_DEFAULT: number | undefined = undefined; // TODO config
const PRESENCE_PENALTY_DEFAULT: number | undefined = undefined; // TODO config
const STOP_SEQUENCES_DEFAULT: Array<string> | undefined = undefined; // TODO config

export interface Zzz_Server_Options {
	send_to_all_clients: (message: Message_Server) => void;
	/**
	 * @default ZZZ_DIR_DEFAULT
	 */
	zzz_dir?: string; // TODO rename to `filesystem_dirs` or something? `zzz_dirs`?
	filer?: Filer;
	// TODO BLOCK @many make these part of the cached tape/completion state, source of truth is where?
	system_message?: string;
	output_token_max?: number;
	temperature?: number;
	seed?: number;
	top_k?: number;
	top_p?: number;
	frequency_penalty?: number;
	presence_penalty?: number;
	stop_sequences?: Array<string>;
}

export class Zzz_Server {
	#send_to_all_clients: (message: Message_Server) => void;

	zzz_dir: string;

	filer: Filer;

	// TODO BLOCK @many make these part of the cached tape/completion state, source of truth is where?
	system_message: string;
	output_token_max: number;
	// TODO add UI for these
	temperature: number;
	seed: number | undefined;
	top_k: number | undefined;
	top_p: number | undefined;
	frequency_penalty: number | undefined;
	presence_penalty: number | undefined;
	stop_sequences: Array<string> | undefined;

	#cleanup_filer: Promise<Cleanup_Watch>;

	constructor(options: Zzz_Server_Options) {
		console.log('create Zzz_Server');
		this.#send_to_all_clients = options.send_to_all_clients;
		this.zzz_dir = options.zzz_dir ?? ZZZ_DIR_DEFAULT;
		this.filer = options.filer ?? new Filer({watch_dir_options: {dir: this.zzz_dir}});
		this.#cleanup_filer = this.filer.watch((change, source_file) => {
			this.handle_filer_change(change, source_file);
		});
		this.system_message = options.system_message ?? SYSTEM_MESSAGE_DEFAULT;
		this.output_token_max = options.output_token_max ?? OUTPUT_TOKEN_MAX_DEFAULT;
		this.temperature = options.temperature ?? TEMPERATURE_DEFAULT;
		this.seed = options.seed ?? SEED_DEFAULT;
		this.top_k = options.top_k ?? TOP_K_DEFAULT;
		this.top_p = options.top_p ?? TOP_P_DEFAULT;
		this.frequency_penalty = options.frequency_penalty ?? FREQUENCY_PENALTY_DEFAULT;
		this.presence_penalty = options.presence_penalty ?? PRESENCE_PENALTY_DEFAULT;
		this.stop_sequences = options.stop_sequences ?? STOP_SEQUENCES_DEFAULT;
	}

	send(message: Message_Server): void {
		this.#send_to_all_clients(message);
	}

	// TODO add an abstraction here, so the server isn't concerned with message content/types
	async receive(message: Message_Client): Promise<Message_Server | null> {
		console.log(`[zzz_server.receive] message`, message.id, message.type);
		switch (message.type) {
			case 'ping': {
				return {
					id: Uuid.parse(undefined),
					type: 'pong',
					ping_id: message.id,
				};
			}
			case 'load_session': {
				// Use encode method directly on the files Map to convert it to a compatible format
				// This replaces the custom source_files_map_to_record function
				const files_record: Record<string, any> = {};

				this.filer.files.forEach((file, id) => {
					const path_id = Diskfile_Path.parse(id);
					files_record[path_id] = {
						...file,
						id: path_id,
						// Maps will be automatically handled by our encode/decode system
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
								temperature: this.temperature,
								seed: this.seed,
								num_predict: this.output_token_max,
								top_k: this.top_k,
								top_p: this.top_p,
								frequency_penalty: this.frequency_penalty,
								presence_penalty: this.presence_penalty,
								stop: this.stop_sequences,
							},
							messages: format_ollama_messages(this.system_message, tape_history, prompt),
						});
						console.log(`ollama api_response`, api_response);
						response = create_completion_response(message.id, provider_name, model, api_response);
						break;
					}

					case 'claude': {
						const api_response = await anthropic.messages.create({
							model,
							max_tokens: this.output_token_max,
							temperature: this.temperature,
							top_k: this.top_k,
							top_p: this.top_p,
							stop_sequences: this.stop_sequences,
							system: this.system_message,
							messages: format_claude_messages(tape_history, prompt),
						});
						console.log(`claude api_response`, api_response);
						response = create_completion_response(message.id, provider_name, model, api_response);
						break;
					}

					case 'chatgpt': {
						const api_response = await openai.chat.completions.create({
							model,
							max_completion_tokens: this.output_token_max,
							temperature: model === 'o1-mini' ? undefined : this.temperature,
							seed: this.seed,
							top_p: this.top_p,
							frequency_penalty: this.frequency_penalty,
							presence_penalty: this.presence_penalty,
							stop: this.stop_sequences,
							messages: format_openai_messages(this.system_message, tape_history, prompt, model),
						});
						console.log(`openai api_response`, api_response);
						response = create_completion_response(message.id, provider_name, model, api_response);
						break;
					}

					case 'gemini': {
						// TODO cache this by model?
						const google_model = google.getGenerativeModel({
							model,
							systemInstruction: this.system_message,
							// TODO
							// tools,
							// toolConfig
							generationConfig: {
								maxOutputTokens: this.output_token_max,
								temperature: this.temperature,
								topK: this.top_k,
								topP: this.top_p,
								frequencyPenalty: this.frequency_penalty,
								presencePenalty: this.presence_penalty,
								stopSequences: this.stop_sequences,
							},
						});

						const content = format_gemini_messages(tape_history, prompt);
						const api_response = await google_model.generateContent(content);
						console.log(`gemini api_response`, api_response);
						response = create_completion_response(message.id, provider_name, model, api_response);
						break;
					}

					default:
						throw new Unreachable_Error(provider_name);
				}

				// don't need to wait for this to finish,
				// the expected file event is now independent of the request
				void save_response(message, response, this.zzz_dir);

				console.log(`got ${provider_name} message`, response.completion_response.data);

				return response; // TODO @many sending the text again is wasteful, need ids
			}
			case 'update_diskfile': {
				const {path, contents} = message;
				write_file_in_scope(path, contents, this.filer.root_dir);
				return null;
			}
			case 'delete_diskfile': {
				const {path} = message;
				delete_diskfile_in_scope(path, this.filer.root_dir);
				return null;
			}
			default:
				throw new Unreachable_Error(message);
		}
	}

	async destroy(): Promise<void> {
		const cleanup_filer = await this.#cleanup_filer;
		await cleanup_filer();
	}

	handle_filer_change(change: Watcher_Change, source_file: Record<string, any>): void {
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

		this.#send_to_all_clients({
			id: Uuid.parse(undefined),
			type: 'filer_change',
			change: api_change,
			source_file: parsed_source_file,
		});
	}
}

// TODO refactor to support multiple storage backends (starting with fs+postgres), maybe something like
// await storage.save_completion_response(r);
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

// TODO extract helpers? response helpers?
// Standardize the response creation pattern across all providers
const create_completion_response = (
	request_id: Uuid,
	provider_name: Provider_Name,
	model: string,
	provider_data: any,
): Message_Completion_Response => {
	return {
		id: Uuid.parse(undefined),
		type: 'completion_response',
		completion_response: {
			created: Datetime_Now.parse(undefined),
			request_id,
			provider_name,
			model,
			data: {type: provider_name, value: provider_data},
		},
	};
};
