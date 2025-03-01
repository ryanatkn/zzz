import {format} from 'date-fns';
import type {Source_File} from '@ryanatkn/gro/filer.js';
import type {Watcher_Change} from '@ryanatkn/gro/watch_dir.js';
import type {Path_Id} from '@ryanatkn/gro/path.js';

import type {Uuid} from '$lib/uuid.js';
import type {Completion_Request, Completion_Response} from '$lib/completion.js';
import {to_completion_response_text} from '$lib/completion.js';
import type {Zzz} from '$lib/zzz.svelte.js';

// Constants for preview length and formatting
export const MESSAGE_PREVIEW_MAX_LENGTH = 50;
export const MESSAGE_DATE_FORMAT = 'MMM d, p';
export const MESSAGE_TIME_FORMAT = 'p';

// Type definitions - these should be moved to a separate module
export type Zzz_Message = Client_Message | Server_Message;

export type Client_Message =
	| Echo_Message
	| Load_Session_Message
	| Send_Prompt_Message
	| Update_File_Message
	| Delete_File_Message;

export type Server_Message =
	| Echo_Message
	| Loaded_Session_Message
	| Filer_Change_Message
	| Receive_Prompt_Message;

export interface Base_Message {
	id: Uuid;
	type: string;
}

/**
 * @client @server
 */
export interface Echo_Message extends Base_Message {
	type: 'echo';
	data: unknown;
}

/**
 * @client
 */
export interface Load_Session_Message extends Base_Message {
	type: 'load_session';
}

/**
 * @server
 */
export interface Loaded_Session_Message extends Base_Message {
	type: 'loaded_session';
	data: {files: Map<Path_Id, Source_File>};
}

/**
 * @server
 */
export interface Filer_Change_Message extends Base_Message {
	type: 'filer_change';
	change: Watcher_Change;
	source_file: Source_File;
}

/**
 * @client
 */
export interface Send_Prompt_Message extends Base_Message {
	type: 'send_prompt';
	completion_request: Completion_Request;
}

/**
 * @server
 */
export interface Receive_Prompt_Message extends Base_Message {
	type: 'completion_response';
	completion_response: Completion_Response;
}

/**
 * @client
 */
export interface Update_File_Message extends Base_Message {
	type: 'update_file';
	file_id: Path_Id;
	contents: string;
}

/**
 * @client
 */
export interface Delete_File_Message extends Base_Message {
	type: 'delete_file';
	file_id: Path_Id;
}

// Extract type from Zzz_Message definition
export type Message_Type = Zzz_Message['type'];
export type Message_Direction = 'client' | 'server' | 'both';

export interface Message_Json {
	id: Uuid;
	type: Message_Type;
	direction: Message_Direction;
	data: unknown;
	created: string;
}

export interface Message_Options {
	zzz: Zzz;
	json: Message_Json;
}

export class Message {
	readonly zzz: Zzz;

	id: Uuid = $state()!;
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
	is_completion: boolean = $derived(this.type === 'completion_response'); // TODO naming smell
	is_session: boolean = $derived(this.type === 'load_session' || this.type === 'loaded_session');
	is_file_related: boolean = $derived(
		this.type === 'update_file' || this.type === 'delete_file' || this.type === 'filer_change',
	);

	prompt_data: Send_Prompt_Message['completion_request'] | null = $derived(
		this.is_prompt ? (this.data as Send_Prompt_Message).completion_request : null,
	);

	completion_data: Receive_Prompt_Message['completion_response'] | null = $derived(
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
