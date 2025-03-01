import type {Source_File} from '@ryanatkn/gro/filer.js';
import type {Watcher_Change} from '@ryanatkn/gro/watch_dir.js';
import type {Path_Id} from '@ryanatkn/gro/path.js';

import type {Uuid} from '$lib/uuid.js';
import type {Completion_Request, Completion_Response} from '$lib/completion.js';
import type {Zzz} from '$lib/zzz.svelte.js';

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
	created_at: string;
}

export interface Message_Options {
	zzz: Zzz;
	json: Message_Json;
}

export class Message {
	zzz: Zzz;

	id: Uuid = $state()!;
	type: Message_Type = $state()!;
	direction: Message_Direction = $state()!;
	data: unknown = $state();
	created_at: string = $state()!;

	constructor(options: Message_Options) {
		const {
			zzz,
			json: {id, type, direction, data, created_at},
		} = options;
		this.zzz = zzz;
		this.id = id;
		this.type = type;
		this.direction = direction;
		this.data = data;
		this.created_at = created_at;
	}

	toJSON(): Message_Json {
		return {
			id: this.id,
			type: this.type,
			direction: this.direction,
			data: this.data,
			created_at: this.created_at,
		};
	}

	get display_name(): string {
		return `${this.type} (${this.direction})`;
	}

	get timestamp(): Date {
		return new Date(this.created_at);
	}
}
