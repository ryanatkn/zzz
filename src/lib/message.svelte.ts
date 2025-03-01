import {format} from 'date-fns';

import type {
	Message_Type,
	Message_Direction,
	Message_Json,
	Send_Prompt_Message,
	Receive_Prompt_Message,
} from '$lib/api.js';
import {
	to_completion_response_text,
	type Completion_Request,
	type Completion_Response,
} from '$lib/completion.js';
import type {Zzz} from '$lib/zzz.svelte.js';

// Constants for preview length and formatting
export const MESSAGE_PREVIEW_MAX_LENGTH = 50;
export const MESSAGE_DATE_FORMAT = 'MMM d, p';
export const MESSAGE_TIME_FORMAT = 'p';

export interface Message_Options {
	zzz: Zzz;
	json: Message_Json;
}

export class Message {
	readonly zzz: Zzz;

	id: string = $state()!;
	type: Message_Type = $state()!;
	direction: Message_Direction = $state()!;
	data: unknown = $state();
	created: string = $state()!;

	created_date: Date = $derived(new Date(this.created));
	created_formatted_time: string = $derived(format(this.created_date, MESSAGE_TIME_FORMAT));
	created_formatted_date: string = $derived(format(this.created_date, MESSAGE_DATE_FORMAT));

	display_name: string = $derived(`${this.type} (${this.direction})`);

	is_echo: boolean = $derived(this.type === 'echo');
	is_prompt: boolean = $derived(this.type === 'send_prompt');
	is_completion: boolean = $derived(this.type === 'completion_response');
	is_session: boolean = $derived(this.type === 'load_session' || this.type === 'loaded_session');
	is_file_related: boolean = $derived(
		this.type === 'update_file' || this.type === 'delete_file' || this.type === 'filer_change',
	);

	prompt_data: Completion_Request | null = $derived(
		this.is_prompt ? (this.data as Send_Prompt_Message).completion_request : null,
	);

	completion_data: Completion_Response | null = $derived(
		this.is_completion ? (this.data as Receive_Prompt_Message).completion_response : null,
	);

	completion_text: string | null | undefined = $derived(
		this.completion_data ? to_completion_response_text(this.completion_data) : null,
	);

	prompt_preview: string = $derived.by(() => {
		if (!this.is_prompt) return 'Not a prompt message';

		const prompt = this.prompt_data?.prompt;
		if (!prompt) return 'No prompt';

		return prompt.length > MESSAGE_PREVIEW_MAX_LENGTH
			? prompt.substring(0, MESSAGE_PREVIEW_MAX_LENGTH) + '...'
			: prompt;
	});

	completion_preview: string = $derived.by(() => {
		if (!this.is_completion) return 'Not a completion message';

		if (!this.completion_text) return 'No completion';

		return this.completion_text.length > MESSAGE_PREVIEW_MAX_LENGTH
			? this.completion_text.substring(0, MESSAGE_PREVIEW_MAX_LENGTH) + '...'
			: this.completion_text;
	});

	constructor(options: Message_Options) {
		const {
			zzz,
			json: {id, type, direction, data, created},
		} = options;
		this.zzz = zzz;
		this.id = id;
		this.type = type;
		this.direction = direction;
		this.data = data;
		this.created = created;
	}

	toJSON(): Message_Json {
		return {
			id: this.id,
			type: this.type,
			direction: this.direction,
			data: this.data,
			created: this.created,
		};
	}
}
