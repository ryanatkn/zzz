import type {Source_File} from '@ryanatkn/gro/filer.js';
import type {Watcher_Change} from '@ryanatkn/gro/watch_dir.js';
import type {Path_Id} from '@ryanatkn/gro/path.js';

import type {Id} from '$lib/id.js';
import type {Completion_Request, Completion_Response} from '$lib/completion.js';

export type Zzz_Message = Client_Message | Server_Message;

export type Client_Message =
	| Echo_Message
	| Load_Session_Message
	| Send_Prompt_Message
	| Update_File_Message;

export type Server_Message =
	| Echo_Message
	| Loaded_Session_Message
	| Filer_Change_Message
	| Receive_Prompt_Message;

export interface Base_Message {
	id: Id; // TODO trusting the client to make these for now because it's simpler
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
	type: 'loaded_session'; // TODO req/res pair instead of separate message?
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
