// @slop Claude Opus 4

import {z} from 'zod';

import {
	Diskfile_Change,
	Diskfile_Directory_Path,
	Diskfile_Path,
	Serializable_Disknode,
} from '$lib/diskfile_types.js';
import {Provider_Status, Provider_Name} from '$lib/provider_types.js';
import {
	Completion_Message,
	Completion_Request,
	Completion_Response,
} from '$lib/completion_types.js';
import type {Action_Spec_Union} from '$lib/action_spec.js';
import {Jsonrpc_Request_Id} from '$lib/jsonrpc.js';
import {
	Ollama_List_Request,
	Ollama_List_Response,
	Ollama_Ps_Request,
	Ollama_Ps_Response,
	Ollama_Show_Request,
	Ollama_Show_Response,
	Ollama_Pull_Request,
	Ollama_Delete_Request,
	Ollama_Copy_Request,
	Ollama_Create_Request,
	Ollama_Progress_Response,
} from '$lib/ollama_helpers.js';
import {Uuid} from '$lib/zod_helpers.js';

// TODO I tried using the helper `create_action_spec` but I don't see how to get proper typing,
// we want the declared specs to have their literal types but not need to include optional
// properties;

export const ping_action_spec = {
	method: 'ping',
	kind: 'request_response',
	initiator: 'both',
	auth: 'public',
	side_effects: null,
	input: z.void().optional(),
	output: z.strictObject({
		ping_id: Jsonrpc_Request_Id,
	}),
	async: true,
} satisfies Action_Spec_Union;

export const session_load_action_spec = {
	method: 'session_load',
	kind: 'request_response',
	// TODO @api is this actually a good restriction to have?
	// or should the server be calling actions internally too?
	initiator: 'frontend',
	auth: 'public',
	side_effects: null,
	input: z.void().optional(),
	output: z.strictObject({
		data: z.strictObject({
			// TODO extract this schema to diskfile_types or something
			zzz_cache_dir: Diskfile_Directory_Path,
			files: z.array(Serializable_Disknode),
			provider_status: z.array(Provider_Status),
		}),
	}),
	async: true,
} satisfies Action_Spec_Union;

export const filer_change_action_spec = {
	method: 'filer_change',
	kind: 'remote_notification',
	initiator: 'backend',
	auth: null,
	side_effects: true,
	input: z.strictObject({
		change: Diskfile_Change,
		disknode: Serializable_Disknode,
	}),
	output: z.void(),
	async: true,
} satisfies Action_Spec_Union;

export const diskfile_update_action_spec = {
	method: 'diskfile_update',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z.strictObject({
		path: Diskfile_Path,
		content: z.string(),
	}),
	output: z.null(),
	async: true,
} satisfies Action_Spec_Union;

export const diskfile_delete_action_spec = {
	method: 'diskfile_delete',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z.strictObject({
		path: Diskfile_Path,
	}),
	output: z.null(),
	async: true,
} satisfies Action_Spec_Union;

export const directory_create_action_spec = {
	method: 'directory_create',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z.strictObject({
		path: Diskfile_Path,
	}),
	output: z.null(),
	async: true,
} satisfies Action_Spec_Union;

export const completion_create_action_spec = {
	method: 'completion_create',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z.strictObject({
		completion_request: Completion_Request,
		_meta: z.looseObject({progressToken: Uuid.optional()}).optional(),
	}),
	output: z.strictObject({
		completion_response: Completion_Response,
		_meta: z.looseObject({progressToken: Uuid.optional()}).optional(),
	}),
	async: true,
} satisfies Action_Spec_Union;

export const completion_progress_action_spec = {
	method: 'completion_progress',
	kind: 'remote_notification',
	initiator: 'backend',
	auth: null,
	side_effects: true,
	input: z.strictObject({
		// TODO improve schema
		// "gemma3:1b"
		// 		interface ChatResponse {
		//     model: string;
		//     created_at: Date;
		//     message: Message;
		//     done: boolean;
		//     done_reason: string;
		//     total_duration: number;
		//     load_duration: number;
		//     prompt_eval_count: number;
		//     prompt_eval_duration: number;
		//     eval_count: number;
		//     eval_duration: number;
		// }
		// Ollama types:
		//		 thinking?: string;
		//		 images?: Uint8Array[] | string[];
		//		 tool_calls?: ToolCall[];
		chunk: z
			.looseObject({
				model: z.string().optional(),
				created_at: z.string().optional(),
				done: z.boolean().optional(),
				message: Completion_Message.optional(),
			})
			.optional(),
		_meta: z.looseObject({progressToken: Uuid.optional()}).optional(),
	}),
	output: z.void(),
	async: true,
} satisfies Action_Spec_Union;

export const ollama_progress_action_spec = {
	method: 'ollama_progress',
	kind: 'remote_notification',
	initiator: 'backend',
	auth: null,
	side_effects: true,
	input: z.strictObject(
		Ollama_Progress_Response.extend({
			_meta: z.looseObject({progressToken: Uuid.optional()}).optional(),
		}).shape,
	),
	output: z.void(),
	async: true,
} satisfies Action_Spec_Union;

// TODO this is just a placeholder for a local call
export const toggle_main_menu_action_spec = {
	method: 'toggle_main_menu',
	kind: 'local_call',
	initiator: 'frontend',
	auth: null,
	side_effects: true,
	input: z.strictObject({show: z.boolean().optional()}).optional(),
	output: z.strictObject({show: z.boolean()}),
	async: false,
} satisfies Action_Spec_Union;

export const ollama_list_action_spec = {
	method: 'ollama_list',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: null,
	input: Ollama_List_Request,
	output: z.union([Ollama_List_Response, z.null()]),
	async: true,
} satisfies Action_Spec_Union;

export const ollama_ps_action_spec = {
	method: 'ollama_ps',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: null,
	input: Ollama_Ps_Request,
	output: z.union([Ollama_Ps_Response, z.null()]),
	async: true,
} satisfies Action_Spec_Union;

export const ollama_show_action_spec = {
	method: 'ollama_show',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: null,
	input: Ollama_Show_Request,
	output: z.union([Ollama_Show_Response, z.null()]),
	async: true,
} satisfies Action_Spec_Union;

export const ollama_pull_action_spec = {
	method: 'ollama_pull',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z.strictObject(
		Ollama_Pull_Request.extend({
			_meta: z.looseObject({progressToken: Uuid.optional()}).optional(),
		}).shape,
	), // TODO @many is strict right here?
	output: z.void().optional(),
	async: true,
} satisfies Action_Spec_Union;

export const ollama_delete_action_spec = {
	method: 'ollama_delete',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: Ollama_Delete_Request,
	output: z.void().optional(),
	async: true,
} satisfies Action_Spec_Union;

export const ollama_copy_action_spec = {
	method: 'ollama_copy',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: Ollama_Copy_Request,
	output: z.void().optional(),
	async: true,
} satisfies Action_Spec_Union;

export const ollama_create_action_spec = {
	method: 'ollama_create',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z.strictObject(
		Ollama_Create_Request.extend({
			_meta: z.looseObject({progressToken: Uuid.optional()}).optional(),
		}).shape,
	), // TODO @many is strict right here?
	output: z.void().optional(),
	async: true,
} satisfies Action_Spec_Union;

export const ollama_unload_action_spec = {
	method: 'ollama_unload',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z.strictObject({
		model: z.string(),
	}),
	output: z.void().optional(),
	async: true,
} satisfies Action_Spec_Union;

export const provider_load_status_action_spec = {
	method: 'provider_load_status',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: null,
	input: z.strictObject({
		provider_name: Provider_Name,
		reload: z.boolean().default(true).optional(),
	}),
	output: z.strictObject({
		status: Provider_Status,
	}),
	async: true,
} satisfies Action_Spec_Union;

export const provider_update_api_key_action_spec = {
	method: 'provider_update_api_key',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z.strictObject({
		provider_name: Provider_Name,
		api_key: z.string(),
	}),
	output: z.strictObject({
		status: Provider_Status,
	}),
	async: true,
} satisfies Action_Spec_Union;
