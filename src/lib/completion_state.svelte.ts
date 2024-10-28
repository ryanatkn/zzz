// TODO BLOCK

// import type {Receive_Prompt_Message, Send_Prompt_Message} from '$lib/zzz_message.js';

// export interface Completion_State_Json {
// 	completion_request: Send_Prompt_Message;
// 	completion_response: Receive_Prompt_Message;
// }

// export interface Completion_State_Options {
// 	data: Completion_State_Json;
// }

// // TODO BLOCK name?
// export class Completion_State {
// 	completion_request: Send_Prompt_Message = $state()!;
// 	completion_response: Receive_Prompt_Message = $state()!;

// 	constructor(options: Completion_State_Options) {
// 		const {
// 			data: {completion_request, completion_response},
// 		} = options;
// 		this.completion_request = completion_request;
// 		this.completion_response = completion_response;
// 	}

// 	toJSON(): Completion_State_Json {
// 		return {
// 			completion_request: this.completion_request,
// 			completion_response: this.completion_response,
// 		};
// 	}
// }
