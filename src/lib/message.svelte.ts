import {format} from 'date-fns';
import {z} from 'zod';

import {Serializable, type Serializable_Options} from '$lib/serializable.svelte.js';
import {
	to_completion_response_text,
	type Completion_Request,
	type Completion_Response,
} from '$lib/completion.js';
import {Uuid} from '$lib/uuid.js';
import {Message_Json, type Message_Direction, type Message_Type} from '$lib/message.schema.js';

// Constants for preview length and formatting
export const MESSAGE_PREVIEW_MAX_LENGTH = 50;
export const MESSAGE_DATE_FORMAT = 'MMM d, p';
export const MESSAGE_TIME_FORMAT = 'p';

// eslint-disable-next-line @typescript-eslint/no-empty-object-type
export interface Message_Options extends Serializable_Options<typeof Message_Json> {}

export class Message extends Serializable<typeof Message_Json> {
	id: Uuid = $state()!;
	type: Message_Type = $state()!;
	direction: Message_Direction = $state()!;
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
		this.is_prompt && this.completion_request ? this.completion_request : null,
	);

	completion_data: Completion_Response | null = $derived(
		this.is_completion && this.completion_response ? this.completion_response : null,
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
		super(Message_Json, options);

		// Initialize base properties
		this.init();

		// TODO BLOCK @many this is hacky
		// Process message-specific fields after properties are set from JSON
		if (options.json) {
			// Initialize type-specific properties based on message type
			switch (this.type) {
				case 'send_prompt':
					if ('completion_request' in options.json) {
						// Direct assignment instead of using helper
						this.completion_request = options.json.completion_request;
					}
					break;
				case 'completion_response':
					if ('completion_response' in options.json) {
						// Direct assignment instead of using helper
						this.completion_response = options.json.completion_response;
					}
					break;
				case 'echo':
					if ('data' in options.json) {
						this.data = options.json.data;
					}
					break;
				case 'update_file':
					if ('file_id' in options.json) {
						this.file_id = options.json.file_id;
						this.contents = options.json.contents;
					}
					break;
				case 'delete_file':
					if ('file_id' in options.json) {
						this.file_id = options.json.file_id;
					}
					break;
				case 'filer_change':
					if ('change' in options.json && 'source_file' in options.json) {
						this.change = options.json.change;
						this.source_file = options.json.source_file;
					}
					break;
				case 'loaded_session':
					if ('data' in options.json) {
						this.data = options.json.data;
					}
					break;
				default:
					// TODO what to do here?
					console.log('unhandled message', this.type, this);
					break;
			}
		}
	}

	override to_json(): z.output<typeof Message_Json> {
		// Create base message data
		const base = {
			id: this.id,
			type: this.type,
			direction: this.direction,
			created: this.created,
		};

		// TODO BLOCK @many this is hacky
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
				return base;
			default:
				return base as z.output<typeof Message_Json>;
		}
	}
}
