import type {Provider} from '$lib/provider.svelte.js';
import type {Completion_Request, Completion_Response} from '$lib/completion.js';
import {random_id, type Id} from '$lib/id.js';
import {zzz_context} from '$lib/zzz.svelte.js';

export interface Chat_Message {
	id: Id;
	timestamp: string;
	request?: Completion_Request;
	response?: Completion_Response;
}

export interface Chat_Instance {
	id: Id;
	provider: Provider;
	model_name: string;
	messages: Array<Chat_Message>;
}

export class Chat {
	instances: Map<Id, Chat_Instance> = $state(new Map());
	zzz = zzz_context.get();

	add_instance(provider: Provider, model_name: string): void {
		const id = random_id();
		this.instances.set(id, {
			id,
			provider,
			model_name,
			messages: [],
		});
	}

	remove_instance(id: Id): void {
		this.instances.delete(id);
	}

	async send_message(text: string): Promise<void> {
		const messages = Array.from(this.instances.values()).map(async (instance) => {
			const msg_id = random_id();
			const message: Chat_Message = {
				id: msg_id,
				timestamp: new Date().toISOString(),
				request: {
					created: new Date().toISOString(),
					request_id: msg_id,
					provider_name: instance.provider.name,
					model: instance.model_name,
					prompt: text,
				},
			};

			instance.messages.push(message);

			const response = await this.zzz.send_prompt(
				text,
				instance.provider.name,
				instance.model_name,
			);

			// TODO refactor
			const msg = instance.messages.find((m) => m.id === msg_id);
			if (msg) msg.response = response.completion_response;
		});

		await Promise.all(messages);
	}
}
