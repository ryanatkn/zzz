import {format} from 'date-fns';

import {
	type Api_Message_With_Metadata,
	type Api_Message_Direction,
	type Api_Message_Type,
	type Api_Send_Prompt_Message,
	type Api_Receive_Prompt_Message,
} from '$lib/api.js';
import {
	to_completion_response_text,
	type Completion_Request,
	type Completion_Response,
} from '$lib/completion.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import {Uuid} from '$lib/uuid.js';

// Constants for preview length and formatting
export const MESSAGE_PREVIEW_MAX_LENGTH = 50;
export const MESSAGE_DATE_FORMAT = 'MMM d, p';
export const MESSAGE_TIME_FORMAT = 'p';

export interface Message_Options {
	zzz: Zzz;
	json: Api_Message_With_Metadata;
}

export class Message {
	readonly zzz: Zzz;

	id: Uuid = $state()!;
	type: Api_Message_Type = $state()!;
	direction: Api_Message_Direction = $state()!;
	created: string = $state()!;

	// Store data based on message type
	data: unknown = $state();
	completion_request: Completion_Request | undefined = $state();
	completion_response: Completion_Response | undefined = $state();
	file_id: string | undefined = $state();
	contents: string | undefined = $state();
	change: any | undefined = $state();
	source_file: any | undefined = $state();

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
		this.is_prompt ? (this.data as Api_Send_Prompt_Message).completion_request : null,
	);

	completion_data: Completion_Response | null = $derived(
		this.is_completion ? (this.data as Api_Receive_Prompt_Message).completion_response : null,
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

	// Update the constructor to handle the different message types
	constructor(options: Message_Options) {
		const {zzz, json} = options;
		this.zzz = zzz;
		this.id = json.id;
		this.type = json.type;
		this.direction = json.direction;
		this.created = json.created;

		// Depending on message type, assign the appropriate properties
		switch (json.type) {
			case 'echo':
				this.data = json.data;
				break;
			case 'send_prompt':
				this.completion_request = json.completion_request;
				break;
			case 'completion_response':
				this.completion_response = json.completion_response;
				break;
			case 'update_file':
				this.file_id = json.file_id;
				this.contents = json.contents;
				break;
			case 'delete_file':
				this.file_id = json.file_id;
				break;
			case 'filer_change':
				this.change = json.change;
				this.source_file = json.source_file;
				break;
			case 'load_session':
				// No additional data
				break;
			case 'loaded_session':
				this.data = json.data;
				break;
		}

		// For backward compatibility, ensure data is populated
		if (this.data === undefined) {
			switch (json.type) {
				case 'send_prompt':
					this.data = {completion_request: this.completion_request};
					break;
				case 'completion_response':
					this.data = {completion_response: this.completion_response};
					break;
				case 'update_file':
					this.data = {file_id: this.file_id, contents: this.contents};
					break;
				case 'delete_file':
					this.data = {file_id: this.file_id};
					break;
				case 'filer_change':
					this.data = {change: this.change, source_file: this.source_file};
					break;
			}
		}
	}

	toJSON(): Api_Message_With_Metadata {
		const base = {
			id: this.id,
			type: this.type,
			direction: this.direction,
			created: this.created,
		};

		// Add type-specific properties
		switch (this.type) {
			case 'echo':
				return {...base, data: this.data};
			case 'send_prompt':
				return {...base, completion_request: this.completion_request};
			case 'completion_response':
				return {...base, completion_response: this.completion_response};
			case 'update_file':
				return {...base, file_id: this.file_id, contents: this.contents};
			case 'delete_file':
				return {...base, file_id: this.file_id};
			case 'filer_change':
				return {...base, change: this.change, source_file: this.source_file};
			case 'loaded_session':
				return {...base, data: this.data};
			case 'load_session':
			default:
				return base;
		}
	}
}
