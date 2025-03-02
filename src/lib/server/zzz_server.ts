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

import {
	type Api_Client_Message,
	type Api_Receive_Prompt_Message,
	type Api_Send_Prompt_Message,
	type Api_Server_Message,
} from '$lib/api.js';
import {Uuid} from '$lib/uuid.js';
import {SYSTEM_MESSAGE_DEFAULT} from '$lib/config.js';
import {delete_file_in_scope, write_file_in_scope} from '$lib/server/helpers.js';
import {map_watcher_change_to_file_change} from '$lib/file_types.js';

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
	send: (message: Api_Server_Message) => void;
	/**
	 * @default ZZZ_DIR_DEFAULT
	 */
	zzz_dir?: string;
	filer?: Filer;
	// TODO BLOCK @many make these part of the cached conversation/completion state, source of truth is where?
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
	#send: (message: Api_Server_Message) => void;

	zzz_dir: string;

	filer: Filer;

	// TODO BLOCK @many make these part of the cached conversation/completion state, source of truth is where?
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
		this.#send = options.send;
		this.zzz_dir = options.zzz_dir ?? ZZZ_DIR_DEFAULT;
		this.filer = options.filer ?? new Filer({watch_dir_options: {dir: this.zzz_dir}});
		this.#cleanup_filer = this.filer.watch((change, source_file) => {
			// Convert watcher change type to API change type
			const api_change = {
				type: map_watcher_change_to_file_change(change.type),
				path: change.path,
			};

			if (source_file.id.includes('.css'))
				console.log(`source_file`, source_file.id, source_file.contents?.length);
			this.#send({
				id: Uuid.parse(undefined),
				type: 'filer_change',
				change: api_change,
				source_file,
			});
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

	send(message: Api_Server_Message): void {
		this.#send(message);
	}

	// TODO add an abstraction here, so the server isn't concerned with message content/types
	async receive(message: Api_Client_Message): Promise<Api_Server_Message | null> {
		console.log(`[zzz_server.receive] message`, message.id, message.type);
		switch (message.type) {
			case 'echo': {
				// await wait(1000);
				return message;
			}
			case 'load_session': {
				return {id: Uuid.parse(undefined), type: 'loaded_session', data: {files: this.filer.files}};
			}
			case 'send_prompt': {
				const {prompt, provider_name, model} = message.completion_request;

				let response: Api_Receive_Prompt_Message;

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
							messages: [
								{role: 'system', content: this.system_message},
								{role: 'user', content: prompt},
								// TODO BLOCK add assistant messages (full history), validate 'user' | 'system' | 'assistant'
							],
						});
						console.log(`ollama api_response`, api_response);
						response = {
							id: Uuid.parse(undefined),
							type: 'completion_response',
							completion_response: {
								created: new Date().toISOString(),
								request_id: message.id,
								provider_name,
								model,
								data: {type: provider_name, value: api_response},
							},
						};
						break;
					}

					case 'claude': {
						const api_response = await anthropic.messages.create({
							model,
							max_tokens: this.output_token_max,
							// TODO
							// tools:
							// tool_choice
							temperature: this.temperature,
							top_k: this.top_k,
							top_p: this.top_p,
							stop_sequences: this.stop_sequences,
							system: this.system_message,
							messages: [{role: 'user', content: [{type: 'text', text: prompt}]}],
						});
						console.log(`claude api_response`, api_response);
						response = {
							id: Uuid.parse(undefined),
							type: 'completion_response',
							completion_response: {
								created: new Date().toISOString(),
								request_id: message.id,
								provider_name,
								model,
								data: {type: provider_name, value: api_response},
							},
						};
						break;
					}

					case 'chatgpt': {
						const api_response = await openai.chat.completions.create({
							model,
							max_completion_tokens: this.output_token_max,
							// TODO
							// tools
							// tool_choice
							// TODO `supports_temperature` flag on model or similar
							temperature: model === 'o1-mini' ? undefined : this.temperature,
							seed: this.seed,
							top_p: this.top_p,
							frequency_penalty: this.frequency_penalty,
							presence_penalty: this.presence_penalty,
							stop: this.stop_sequences,
							messages: [
								// TODO `supports_system_message` flag on model or similar
								model === 'o1-mini'
									? null
									: ({role: 'system', content: this.system_message} as const),
								{role: 'user', content: prompt} as const,
							].filter((m) => !!m),
						});
						console.log(`openai api_response`, api_response);
						response = {
							id: Uuid.parse(undefined),
							type: 'completion_response',
							completion_response: {
								created: new Date().toISOString(),
								request_id: message.id,
								provider_name,
								model,
								data: {type: provider_name, value: api_response},
							},
						};
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
						const api_response = await google_model.generateContent(prompt);
						console.log(`gemini api_response`, api_response);
						response = {
							id: Uuid.parse(undefined),
							type: 'completion_response',
							completion_response: {
								created: new Date().toISOString(),
								request_id: message.id,
								provider_name,
								model,
								data: {
									type: provider_name,
									// some of these are functions, and we want `null` for full JSON documents, so manually spelling them out:
									value: {
										text: api_response.response.text(),
										candidates: api_response.response.candidates ?? null,
										function_calls: api_response.response.functionCalls() ?? null,
										prompt_feedback: api_response.response.promptFeedback ?? null,
										usage_metadata: api_response.response.usageMetadata ?? null,
									},
								},
							},
						};
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
			case 'update_file': {
				const {file_id, contents} = message;
				write_file_in_scope(file_id, contents, this.filer.root_dir);
				return null;
			}
			case 'delete_file': {
				const {file_id} = message;
				delete_file_in_scope(file_id, this.filer.root_dir);
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
}

// TODO refactor to support multiple storage backends (starting with fs+postgres), maybe something like
// await storage.save_completion_response(r);
const save_response = async (
	request: Api_Send_Prompt_Message,
	response: Api_Receive_Prompt_Message,
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
