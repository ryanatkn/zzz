// @slop claude_opus_4

import {z} from 'zod';

import {
	Diskfile_Change,
	Diskfile_Path,
	Serializable_Source_File,
	Zzz_Dir,
} from '$lib/diskfile_types.js';
import {Completion_Request, Completion_Response} from '$lib/completion_types.js';
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
} from '$lib/ollama_helpers.js';

// TODO I tried using the helper `create_action_spec` but I don't see how to get proper typing,
// we want the declared specs to have their literal types but not need to include optional properties

export const ping_action_spec = {
	method: 'ping',
	kind: 'request_response',
	initiator: 'both',
	auth: 'public',
	side_effects: null,
	input: z.void().optional(),
	output: z
		.object({
			ping_id: Jsonrpc_Request_Id,
		})
		.strict(),
	async: true,
} satisfies Action_Spec_Union;

export const load_session_action_spec = {
	method: 'load_session',
	kind: 'request_response',
	// TODO @api is this actually a good restriction to have?
	// or should the server be calling actions internally too?
	initiator: 'frontend',
	auth: 'public',
	side_effects: null,
	input: z.void().optional(),
	output: z
		.object({
			data: z
				// TODO extract this schema to diskfile_types or something
				.object({
					zzz_dir: Zzz_Dir,
					zzz_cache_dir: Diskfile_Path,
					files: z.array(Serializable_Source_File),
				})
				.strict(),
		})
		.strict(),
	async: true,
} satisfies Action_Spec_Union;

export const filer_change_action_spec = {
	method: 'filer_change',
	kind: 'remote_notification',
	initiator: 'backend',
	auth: null,
	side_effects: true,
	input: z
		.object({
			change: Diskfile_Change,
			source_file: Serializable_Source_File,
		})
		.strict(),
	output: z.void(),
	async: true,
} satisfies Action_Spec_Union;

export const update_diskfile_action_spec = {
	method: 'update_diskfile',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z
		.object({
			path: Diskfile_Path,
			content: z.string(),
		})
		.strict(),
	output: z.null(),
	async: true,
} satisfies Action_Spec_Union;

export const delete_diskfile_action_spec = {
	method: 'delete_diskfile',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z
		.object({
			path: Diskfile_Path,
		})
		.strict(),
	output: z.null(),
	async: true,
} satisfies Action_Spec_Union;

export const create_directory_action_spec = {
	method: 'create_directory',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z
		.object({
			path: Diskfile_Path,
		})
		.strict(),
	output: z.null(),
	async: true,
} satisfies Action_Spec_Union;

export const submit_completion_action_spec = {
	method: 'submit_completion',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z
		.object({
			completion_request: Completion_Request,
		})
		.strict(),
	output: z
		.object({
			completion_response: Completion_Response,
		})
		.strict(),
	async: true,
} satisfies Action_Spec_Union;

// TODO this is just a placeholder for a local call
export const toggle_main_menu_action_spec = {
	method: 'toggle_main_menu',
	kind: 'local_call',
	initiator: 'frontend',
	auth: null,
	side_effects: true,
	input: z.object({show: z.boolean().optional()}).optional(),
	output: z.object({show: z.boolean()}),
	async: false,
} satisfies Action_Spec_Union;

export const ollama_list_action_spec = {
	method: 'ollama_list',
	kind: 'local_call',
	initiator: 'frontend',
	auth: null,
	side_effects: null,
	input: Ollama_List_Request,
	output: Ollama_List_Response,
	async: true,
} satisfies Action_Spec_Union;

export const ollama_ps_action_spec = {
	method: 'ollama_ps',
	kind: 'local_call',
	initiator: 'frontend',
	auth: null,
	side_effects: null,
	input: Ollama_Ps_Request,
	output: Ollama_Ps_Response,
	async: true,
} satisfies Action_Spec_Union;

export const ollama_show_action_spec = {
	method: 'ollama_show',
	kind: 'local_call',
	initiator: 'frontend',
	auth: null,
	side_effects: null,
	input: Ollama_Show_Request,
	output: Ollama_Show_Response,
	async: true,
} satisfies Action_Spec_Union;

export const ollama_pull_action_spec = {
	method: 'ollama_pull',
	kind: 'local_call',
	initiator: 'frontend',
	auth: null,
	side_effects: true,
	input: Ollama_Pull_Request,
	output: z.void().optional(),
	async: true,
} satisfies Action_Spec_Union;

export const ollama_delete_action_spec = {
	method: 'ollama_delete',
	kind: 'local_call',
	initiator: 'frontend',
	auth: null,
	side_effects: true,
	input: Ollama_Delete_Request,
	output: z.void().optional(),
	async: true,
} satisfies Action_Spec_Union;

export const ollama_copy_action_spec = {
	method: 'ollama_copy',
	kind: 'local_call',
	initiator: 'frontend',
	auth: null,
	side_effects: true,
	input: Ollama_Copy_Request,
	output: z.void().optional(),
	async: true,
} satisfies Action_Spec_Union;

export const ollama_create_action_spec = {
	method: 'ollama_create',
	kind: 'local_call',
	initiator: 'frontend',
	auth: null,
	side_effects: true,
	input: Ollama_Create_Request,
	output: z.void().optional(),
	async: true,
} satisfies Action_Spec_Union;
