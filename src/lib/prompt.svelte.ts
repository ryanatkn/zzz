import type {Receive_Prompt_Message, Send_Prompt_Message} from './zzz_message.js';

export interface Prompt_Json {
	model: string;
	request: Send_Prompt_Message;
	response: Receive_Prompt_Message;
}

export interface Prompt_Options {
	data: Prompt_Json;
}

export class Prompt {
	model: string = $state()!; // TODO implement
	request: Send_Prompt_Message = $state()!;
	response: Receive_Prompt_Message = $state()!;

	// TODO
	// models

	constructor(options: Prompt_Options) {
		const {
			data: {model, request, response},
		} = options;
		this.model = model;
		this.request = request;
		this.response = response;
	}

	toJSON(): Prompt_Json {
		return {
			model: this.model,
			request: this.request,
			response: this.response,
		};
	}
}
