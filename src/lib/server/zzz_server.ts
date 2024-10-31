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
import {join} from 'node:path';
import {format_file} from '@ryanatkn/gro/format_file.js';

import type {
	Client_Message,
	Receive_Prompt_Message,
	Send_Prompt_Message,
	Server_Message,
} from '$lib/zzz_message.js';
import {random_id} from '$lib/id.js';
import {SYSTEM_MESSAGE_DEFAULT} from '$lib/config.js';
import {write_file_in_scope as write_file_in_root_dir} from '$lib/server/helpers.js';

const anthropic = new Anthropic({apiKey: SECRET_ANTHROPIC_API_KEY});
const openai = new OpenAI({apiKey: SECRET_OPENAI_API_KEY});
const google = new GoogleGenerativeAI(SECRET_GOOGLE_API_KEY);

const ZZZ_DIR_DEFAULT = './.zzz';

export interface Options {
	send: (message: Server_Message) => void;
	/**
	 * @default ZZZ_DIR_DEFAULT
	 */
	zzz_dir?: string;
	filer?: Filer;
	system_message?: string;
}

export class Zzz_Server {
	#send: (message: Server_Message) => void;

	zzz_dir: string;

	filer: Filer;

	system_message: string;

	#cleanup_filer: Promise<Cleanup_Watch>;

	constructor(options: Options) {
		console.log('create Zzz_Server');
		this.#send = options.send;
		this.zzz_dir = options.zzz_dir ?? ZZZ_DIR_DEFAULT;
		this.filer = options.filer ?? new Filer({watch_dir_options: {dir: this.zzz_dir}});
		this.#cleanup_filer = this.filer.watch((change, source_file) => {
			switch (change.type) {
				case 'add':
				case 'update':
				case 'delete': {
					if (source_file.id.includes('.css'))
						console.log(`source_file`, source_file.id, source_file.contents?.length);
					this.#send({id: random_id(), type: 'filer_change', change, source_file});
					break;
				}
				default:
					throw new Unreachable_Error(change.type);
			}
		});
		this.system_message = options.system_message ?? SYSTEM_MESSAGE_DEFAULT;
	}

	send(message: Server_Message): void {
		this.#send(message);
	}

	// TODO add an abstraction here, so the server isn't concerned with message content/types
	async receive(request: Client_Message): Promise<Server_Message | null> {
		console.log(`[zzz_server.receive] message`, request.id, request.type);
		switch (request.type) {
			case 'echo': {
				// await wait(1000);
				return request;
			}
			case 'load_session': {
				return {id: random_id(), type: 'loaded_session', data: {files: this.filer.files}};
			}
			case 'send_prompt': {
				const {prompt, agent_name, model} = request.completion_request;

				let response: Receive_Prompt_Message;

				console.log(`texting ${agent_name}`, prompt.substring(0, 1000));

				switch (agent_name) {
					case 'claude': {
						const api_response = await anthropic.messages.create({
							model,
							max_tokens: 1000,
							temperature: 0,
							system: this.system_message,
							messages: [{role: 'user', content: [{type: 'text', text: prompt}]}],
						});
						console.log(`claude api_response`, api_response);
						response = {
							id: random_id(),
							type: 'completion_response',
							completion_response: {
								request_id: request.id,
								agent_name,
								model,
								data: {type: 'claude', value: api_response},
							},
						};
						break;
					}

					case 'chatgpt': {
						const api_response = await openai.chat.completions.create({
							model,
							messages: [
								{role: 'system', content: this.system_message},
								{role: 'user', content: prompt},
							],
						});
						console.log(`openai api_response`, api_response);
						response = {
							id: random_id(),
							type: 'completion_response',
							completion_response: {
								request_id: request.id,
								agent_name,
								model,
								data: {type: 'chatgpt', value: api_response},
							},
						};
						break;
					}

					case 'gemini': {
						// TODO cache this by model?
						const google_model = google.getGenerativeModel({
							model,
							systemInstruction: this.system_message,
						});
						const api_response = await google_model.generateContent(prompt);
						console.log(`gemini api_response`, api_response);
						response = {
							id: random_id(),
							type: 'completion_response',
							completion_response: {
								request_id: request.id,
								agent_name,
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
							},
						};
						break;
					}

					default:
						throw new Unreachable_Error(agent_name);
				}

				// don't need to wait for this to finish,
				// the expected file event is now independent of the request
				void save_response(request, response, this.zzz_dir);

				console.log(`got ${agent_name} message`, response.completion_response.data);

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
// await storage.save_completion_response(r);
const save_response = async (
	request: Send_Prompt_Message,
	response: Receive_Prompt_Message,
	dir: string,
): Promise<void> => {
	const filename = `${request.completion_request.agent_name}__${request.completion_request.model}__${response.id}.json`; // TODO include model data in these

	const path = join(dir, filename);

	const json = {request, response}; // TODO type?

	writeFileSync(path, await format_file(JSON.stringify(json), {parser: 'json'}));
};
