import {format} from 'date-fns';
import {z} from 'zod';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {
	to_completion_response_text,
	Completion_Request,
	Completion_Response,
	type Completion_Request as Completion_Request_Type,
} from '$lib/completion.js';
import {Uuid} from '$lib/uuid.js';
import {Message_Json, type Message_Direction, type Message_Type} from '$lib/message_types.js';
import type {Datetime_Now} from '$lib/zod_helpers.js';
import {Diskfile_Path} from '$lib/diskfile_types.js';

// Constants for preview length and formatting
export const MESSAGE_PREVIEW_MAX_LENGTH = 50;
export const MESSAGE_DATE_FORMAT = 'MMM d, p';
export const MESSAGE_TIME_FORMAT = 'p';

// eslint-disable-next-line @typescript-eslint/no-empty-object-type
export interface Message_Options extends Cell_Options<typeof Message_Json> {}

// TODO think about splitting out a different non-reactive version
// that only handles the static expectation,
// but then another for dynamic usage? is there even such a thing of a message changing?
// if not shouldn't we just remove the $state below?
export class Message extends Cell<typeof Message_Json> {
	id: Uuid = $state()!;
	type: Message_Type = $state()!;
	direction: Message_Direction = $state()!;
	created: Datetime_Now = $state()!;

	// Store data based on message type
	data: Record<string, any> | undefined = $state();
	ping_id: Uuid | undefined = $state();
	completion_request: Completion_Request_Type | undefined = $state();
	completion_response: Completion_Response | undefined = $state();
	path: Diskfile_Path | undefined = $state();
	contents: string | undefined = $state();
	change: any | undefined = $state(); // TODO schema types
	source_file: any | undefined = $state(); // TODO schema types

	created_date: Date = $derived(new Date(this.created));
	created_formatted_time: string = $derived(format(this.created_date, MESSAGE_TIME_FORMAT));
	created_formatted_date: string = $derived(format(this.created_date, MESSAGE_DATE_FORMAT));

	display_name: string = $derived(`${this.type} (${this.direction})`);

	// TODO maybe change these to be located on `this.type` as a `Message_Type_Name` class which JSON serializes to the string `Message_Type` but at runtime has properties like these:
	is_ping: boolean = $derived(this.type === 'ping');
	is_pong: boolean = $derived(this.type === 'pong');
	is_prompt: boolean = $derived(this.type === 'send_prompt');
	is_completion: boolean = $derived(this.type === 'completion_response');
	is_session: boolean = $derived(this.type === 'load_session' || this.type === 'loaded_session');
	is_file_related: boolean = $derived(
		this.type === 'update_diskfile' ||
			this.type === 'delete_diskfile' ||
			this.type === 'filer_change',
	);

	prompt_data: Completion_Request_Type | null = $derived(
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
	}

	// Override the decode_value method to handle type-specific properties
	override decode_value(value: unknown, key: string): unknown {
		// First use the base class implementation for general cases
		const decoded = super.decode_value(value, key);

		// Then handle specific fields based on message type and key
		if (this.type && key === 'completion_request' && this.type === 'send_prompt') {
			return Completion_Request.parse(value);
		} else if (this.type && key === 'completion_response' && this.type === 'completion_response') {
			return Completion_Response.parse(value);
		} else if (this.type && key === 'ping_id' && this.type === 'pong') {
			return Uuid.parse(value);
		} else if (
			(this.type === 'update_diskfile' || this.type === 'delete_diskfile') &&
			key === 'path'
		) {
			return Diskfile_Path.parse(value);
		}

		return decoded;
	}

	// TODO make this automated with the schemas
	override to_json(): z.output<typeof Message_Json> {
		// Create base message data
		const base = {
			id: this.id,
			type: this.type,
			direction: this.direction,
			created: this.created,
		};

		// Add type-specific properties
		switch (this.type) {
			case 'ping':
				return base;
			case 'pong':
				return {...base, ping_id: this.ping_id};
			case 'send_prompt':
				return {...base, completion_request: this.completion_request};
			case 'completion_response':
				return {...base, completion_response: this.completion_response};
			case 'update_diskfile':
				return {...base, path: this.path, contents: this.contents};
			case 'delete_diskfile':
				return {...base, path: this.path};
			case 'filer_change':
				return {...base, change: this.change, source_file: this.source_file};
			case 'loaded_session':
				return {...base, data: this.data};
			case 'load_session':
				return base;
			default:
				throw new Unreachable_Error(this.type);
		}
	}
}
