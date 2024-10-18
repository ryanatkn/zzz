import {Unreachable_Error} from '@ryanatkn/belt/error.js';
import Anthropic from '@anthropic-ai/sdk';
import OpenAI from 'openai';
import {GoogleGenerativeAI} from '@google/generative-ai';
import {Filer, type Cleanup_Watch} from '@ryanatkn/gro/filer.js';
import {
	SECRET_ANTHROPIC_API_KEY,
	SECRET_GOOGLE_API_KEY,
	SECRET_OPENAI_API_KEY,
} from '$env/static/private';
import {writeFileSync} from 'node:fs';
import {format_file} from '@ryanatkn/gro/format_file.js';

import type {
	Client_Message,
	Receive_Prompt_Message,
	Send_Prompt_Message,
	Server_Message,
} from '$lib/zzz_message.js';
import type {Prompt_Json} from '$lib/prompt.svelte.js';
import {random_id} from '$lib/id.js';
import type {Model_Type, Models} from '$lib/config_helpers.js';
import {default_models, SYSTEM_MESSAGE_DEFAULT} from '$lib/config.js';
import {write_file_in_scope as write_file_in_root_dir} from '$lib/server/helpers.js';

const anthropic = new Anthropic({apiKey: SECRET_ANTHROPIC_API_KEY});
const openai = new OpenAI({apiKey: SECRET_OPENAI_API_KEY});
const google = new GoogleGenerativeAI(SECRET_GOOGLE_API_KEY);

export interface Options {
	send: (message: Server_Message) => void;
	filer?: Filer;
	models?: Models;
	default_model_type?: Model_Type;
	system_message?: string;
}

export class Zzz_Server {
	#send: (message: Server_Message) => void;

	filer: Filer;

	default_model_type: Model_Type;
	models: Models;
	system_message: string;

	#cleanup_filer: Promise<Cleanup_Watch>;

	constructor(options: Options) {
		console.log('create Zzz_Server');
		this.#send = options.send;
		this.filer = options.filer ?? new Filer();
		this.#cleanup_filer = this.filer.watch((change, source_file) => {
			switch (change.type) {
				case 'add':
				case 'update':
				case 'delete': {
					if (source_file.id.includes('.css')) console.log(`source_file`, source_file);
					this.#send({id: random_id(), type: 'filer_change', change, source_file});
					break;
				}
				default:
					throw new Unreachable_Error(change.type);
			}
		});
		this.models = options.models ?? default_models;
		this.default_model_type = options.default_model_type ?? 'cheap';
		this.system_message = options.system_message ?? SYSTEM_MESSAGE_DEFAULT;
	}

	send(message: Server_Message): void {
		this.#send(message);
	}

	// TODO add an abstraction here, so the server isn't concerned with message content/types
	async receive(request: Client_Message): Promise<Server_Message | null> {
		console.log(`[zzz_server.receive] message`, request, request.type === 'load_session');
		switch (request.type) {
			case 'echo': {
				// await wait(1000);
				return request;
			}
			case 'load_session': {
				return {id: random_id(), type: 'loaded_session', data: {files: this.filer.files}};
			}
			case 'send_prompt': {
				const {text, agent_name} = request;

				let response: Receive_Prompt_Message;

				console.log(`texting ${agent_name}`, text.substring(0, 1000));

				const model = this.models[agent_name][this.default_model_type];

				switch (agent_name) {
					case 'claude': {
						const api_response = await anthropic.messages.create({
							model,
							max_tokens: 1000,
							temperature: 0,
							system: this.system_message,
							messages: [{role: 'user', content: [{type: 'text', text}]}],
						});
						console.log(`claude api_response`, api_response);
						response = {
							id: random_id(),
							type: 'prompt_response',
							request_id: request.id,
							agent_name: request.agent_name,
							model,
							data: {type: 'claude', value: api_response},
						};
						break;
					}

					case 'gpt': {
						const api_response = await openai.chat.completions.create({
							model,
							messages: [
								{role: 'system', content: this.system_message},
								{role: 'user', content: text},
							],
						});
						console.log(`openai api_response`, api_response);
						const api_response_text = api_response.choices[0].message;
						response = {
							id: random_id(),
							type: 'prompt_response',
							request_id: request.id,
							agent_name: request.agent_name,
							model,
							data: {type: 'gpt', value: api_response_text},
						};
						break;
					}

					case 'gemini': {
						const google_model = google.getGenerativeModel({model});
						const api_response = await google_model.generateContent(
							this.system_message + '\n\n' + text,
						);
						console.log(`gemini api_response`, api_response);
						response = {
							id: random_id(),
							type: 'prompt_response',
							request_id: request.id,
							agent_name: request.agent_name,
							model,
							data: {
								type: 'gemini',
								// some of these are functions, and we want `null` for full JSON documents, so manually spelling them out:
								value: {
									text: api_response.response.text(),
									candidates: api_response.response.candidates ?? null,
									function_calls: api_response.response.functionCalls() ?? null,
									prompt_feedback: api_response.response.promptFeedback ?? null,
									usage_metadata: api_response.response.usageMetadata ?? null,
								},
							},
						};
						break;
					}

					default:
						throw new Unreachable_Error(agent_name);
				}

				// don't need to wait for this to finish,
				// the expected file event is now independent of the request
				void save_response(request, response, this.models[agent_name][this.default_model_type]);

				console.log(`got ${agent_name} message`, response.data);

				return response; // TODO @many sending the text again is wasteful, need ids
			}
			case 'update_file': {
				const {file_id, contents} = request;
				write_file_in_root_dir(file_id, contents, this.filer.root_dir);
				return null;
			}
			default:
				throw new Unreachable_Error(request);
		}
	}

	async destroy(): Promise<void> {
		const cleanup_filer = await this.#cleanup_filer;
		await cleanup_filer();
	}
}

// TODO refactor to support multiple storage backends (starting with fs+postgres), maybe something like
// await storage.save_prompt_response(r);
const save_response = async (
	request: Send_Prompt_Message,
	response: Receive_Prompt_Message,
	model: string,
): Promise<void> => {
	const filename = `${request.agent_name}__${model}__${response.id}.json`; // TODO include model data in these

	const path = `./src/lib/prompts/` + filename;

	const json: Prompt_Json = {model, request, response};

	writeFileSync(path, await format_file(JSON.stringify(json), {parser: 'json'}));
};
