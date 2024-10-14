import {Unreachable_Error} from '@ryanatkn/belt/error.js';
import * as devalue from 'devalue';
import Anthropic from '@anthropic-ai/sdk';
import {Filer, type Cleanup_Watch} from '@ryanatkn/gro/filer.js';
import {SECRET_ANTHROPIC_API_KEY} from '$env/static/private';
import {writeFileSync} from 'node:fs';

import type {Client_Message, Prompt_Response_Message, Server_Message} from '$lib/zzz_message.js';

// SECRET_ANTHROPIC_API_KEY
// SECRET_OPENAI_API_KEY
// SECRET_GOOGLE_API_KEY
const anthropic = new Anthropic({apiKey: SECRET_ANTHROPIC_API_KEY});

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
					this.#send({type: 'filer_change', change, source_file}); // TODO BLOCK shouldn't send unless inited
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
	async receive(message: Client_Message): Promise<Server_Message | null> {
		console.log(`[zzz_server.receive] message`, message, message.type === 'load_session');
		switch (message.type) {
			case 'echo': {
				return message;
			}
			case 'load_session': {
				return {
					type: 'loaded_session',
					data: {files: this.filer.files},
				};
			}
			case 'send_prompt': {
				const {text} = message;
				console.log(`texting Claude`, text);
				const data = await anthropic.messages.create({
					model: 'claude-3-5-sonnet-20240620',
					max_tokens: 1000,
					temperature: 0,
					system:
						'respond with the shortest sentence possible to describe the current context with reasonable clarity',
					messages: [{role: 'user', content: [{type: 'text', text}]}],
				});
				console.log(`got Claude message`, data);

				// TODO refactor to support multiple storage backends (starting with fs+postgres), maybe something like:
				// await storage.save_prompt_response(r);
				const r: Prompt_Response_Message = {type: 'prompt_response', text, data};
				const path = `./src/lib/prompts/${data.id}__${data.model}.json`;
				writeFileSync(path, JSON.stringify(r, null, '\t'));

				return r; // TODO @many sending the text again is wasteful, need ids
			}
			default:
				throw new Unreachable_Error(message);
		}
	}

	async destroy(): Promise<void> {
		await (
			await this.#cleanup_filer
		)();
	}
}
