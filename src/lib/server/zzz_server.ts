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

// SECRET_ANTHROPIC_API_KEY
// SECRET_OPENAI_API_KEY
// SECRET_GOOGLE_API_KEY
const ANTHROPIC_MODEL = 'claude-3-5-sonnet-20240620';
const OPENAI_MODEL = 'gpt-4o';
const GOOGLE_MODEL = 'gemini-1.5-pro';
const anthropic = new Anthropic({apiKey: SECRET_ANTHROPIC_API_KEY});
const openai = new OpenAI({apiKey: SECRET_OPENAI_API_KEY});
const google = new GoogleGenerativeAI(SECRET_GOOGLE_API_KEY);
const google_model = google.getGenerativeModel({model: GOOGLE_MODEL}); // TODO flag for messy dev that uses `gemini-1.5-flash` instead of `gemini-1.5-pro`

export interface Options {
	send: (message: Server_Message) => void;
	filer?: Filer;
}

export class Zzz_Server {
	#send: (message: Server_Message) => void;

	filer: Filer;

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
					this.#send({type: 'filer_change', change, source_file});
					break;
				}
				default:
					throw new Unreachable_Error(change.type);
			}
		});
	}

	send(message: Server_Message): void {
		this.#send(message);
	}

	// TODO add an abstraction here, so the server isn't concerned with message content/types
	async receive(request: Client_Message): Promise<Server_Message | null> {
		console.log(`[zzz_server.receive] message`, request, request.type === 'load_session');
		switch (request.type) {
			case 'echo': {
				return request;
			}
			case 'load_session': {
				return {
					type: 'loaded_session',
					data: {files: this.filer.files},
				};
			}
			case 'send_prompt': {
				const {text, agent_name} = request;

				let response: Receive_Prompt_Message;

				console.log(`texting ${agent_name}`, text);

				switch (agent_name) {
					case 'claude': {
						const api_response = await anthropic.messages.create({
							model: ANTHROPIC_MODEL,
							max_tokens: 1000,
							temperature: 0,
							system:
								'respond with the shortest sentence possible to describe the current context with reasonable clarity',
							messages: [{role: 'user', content: [{type: 'text', text}]}],
						});
						console.log(`claude api_response`, api_response);
						response = {
							type: 'prompt_response',
							agent_name: request.agent_name,
							text,
							data: {type: 'anthropic', value: api_response},
						};
						console.log(`got Claude message`, api_response);
						break;
					}

					case 'chatgpt': {
						console.log(`texting OpenAI`, request.agent_name); // TODO model
						const api_response = await openai.chat.completions.create({
							model: OPENAI_MODEL,
							messages: [
								// TODO needs to be uniform across agents
								{role: 'system', content: 'You are a helpful assistant.'},
								{role: 'user', content: text},
							],
						});
						console.log(`openai api_response`, api_response);
						const api_response_text = api_response.choices[0].message;
						response = {
							type: 'prompt_response',
							agent_name: request.agent_name,
							text,
							data: {type: 'openai', value: api_response_text},
						};
						console.log(`got OpenAI message`, response.data);
						break;
					}

					case 'gemini': {
						console.log(`texting Gemini`, request.agent_name); // TODO model
						const api_response = await google_model.generateContent(text);
						console.log(`gemini api_response`, api_response);
						response = {
							type: 'prompt_response',
							agent_name: request.agent_name,
							text,
							data: {
								type: 'google',
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
						console.log(`got Gemini message`, response.data);
						break;
					}

					default:
						throw new Unreachable_Error(agent_name);
				}

				// don't need to wait for this to finish,
				// the expected file event is now independent of the request
				void save_response(request, response);

				return response; // TODO @many sending the text again is wasteful, need ids
			}
			case 'update_file': {
				const {id, contents} = request;
				writeFileSync(id, contents, 'utf8');
				return null;
			}
			default:
				throw new Unreachable_Error(request);
		}
	}

	async destroy(): Promise<void> {
		await (
			await this.#cleanup_filer
		)();
	}
}

// TODO refactor to support multiple storage backends (starting with fs+postgres), maybe something like
// await storage.save_prompt_response(r);
const save_response = async (
	request: Send_Prompt_Message,
	response: Receive_Prompt_Message,
): Promise<void> => {
	let filename;
	switch (response.data.type) {
		case 'anthropic':
			filename = `anthropic_${response.data.value.id}__${response.data.value.model}.json`;
			break;
		case 'google':
			filename = `google_TODO.json`;
			break;
		case 'openai':
			filename = `openai_TODO.json`;
			break;
		default:
			throw new Unreachable_Error(response.data);
	}

	const path = `./src/lib/prompts/` + filename;

	const json: Prompt_Json = {request, response};

	writeFileSync(path, await format_file(JSON.stringify(json), {parser: 'json'}));
};
