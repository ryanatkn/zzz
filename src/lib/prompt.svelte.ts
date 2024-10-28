import type {Receive_Prompt_Message, Send_Prompt_Message} from '$lib/zzz_message.js';

export interface Prompt_Json {
	request: Send_Prompt_Message;
	response: Receive_Prompt_Message;
}

export interface Prompt_Options {
	data: Prompt_Json;
}

export class Prompt {
	request: Send_Prompt_Message = $state()!;
	response: Receive_Prompt_Message = $state()!;

	constructor(options: Prompt_Options) {
		const {
			data: {request, response},
		} = options;
		this.request = request;
		this.response = response;
	}

	toJSON(): Prompt_Json {
		return {
			request: this.request,
			response: this.response,
		};
	}
}
