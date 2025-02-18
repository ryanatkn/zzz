import type {Model} from '$lib/model.svelte.js';
import type {Completion_Request, Completion_Response} from '$lib/completion.js';
import {random_id, type Id} from '$lib/id.js';
import {zzz_context} from '$lib/zzz.svelte.js';

export interface Chat_Message {
	id: Id;
	timestamp: string;
	text: string;
	request?: Completion_Request;
	response?: Completion_Response;
}

export interface Chat_Stream {
	id: Id;
	model: Model;
	messages: Array<Chat_Message>;
}

export class Multichat {
	streams: Array<Chat_Stream> = $state([]);
	zzz = zzz_context.get();

	add_stream(model: Model): void {
		this.streams.push({
			id: random_id(),
			model,
			messages: [],
		});
	}

	remove_stream(id: Id): void {
		const idx = this.streams.findIndex((s) => s.id === id);
		if (idx !== -1) this.streams.splice(idx, 1);
	}

	async send_to_all(text: string): Promise<void> {
		await Promise.all(this.streams.map((stream) => this.send_to_stream(stream.id, text)));
	}

	async send_to_stream(stream_id: Id, text: string): Promise<void> {
		const stream = this.streams.find((s) => s.id === stream_id);
		if (!stream) return;

		const msg_id = random_id();
		const message: Chat_Message = {
			id: msg_id,
			timestamp: new Date().toISOString(),
			text,
			request: {
				created: new Date().toISOString(),
				request_id: msg_id,
				provider_name: stream.model.provider_name,
				model: stream.model.name,
				prompt: text,
			},
		};

		stream.messages.push(message);

		const response = await this.zzz.send_prompt(
			text,
			stream.model.provider_name,
			stream.model.name,
		);

		const msg = stream.messages.find((m) => m.id === msg_id);
		if (msg) msg.response = response.completion_response;
	}
}
