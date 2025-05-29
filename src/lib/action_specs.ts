import {z} from 'zod';

import type {Action_Spec} from '$lib/action_spec.js';
import {
	Diskfile_Change,
	Diskfile_Path,
	Serializable_Source_File,
	Zzz_Dir,
} from '$lib/diskfile_types.js';
import {Type_Literal, Uuid} from '$lib/zod_helpers.js';
import {Completion_Request, Completion_Response} from '$lib/completion_types.js';

// Action specs are the source of truth for many things including generated code -
// the goal is to make the system extensible for users but it's not there yet.

// TODO BLOCK @api need to rethink the design to fix numerous issues while preserving the desired properties
// - must support JSON-RPC and MCP (which has some opinions/restrictions on top of JSON-RPC)
// - functions can be wrapped on the client and remain synchronous or be async, but on the server handlers are always async.
// 		maybe this restriction isn't desired though? and sync should be allowed?
// - the client and server can both send notifications as well as request/response messages,
// 		so the server can query the client as needed, but the client can always deny requests
// - "params" overloaded for "action messages" so the result of responses is weirdly called params

export const ping_action_spec = {
	method: 'ping',
	kind: 'request_response',
	operation: 'query',
	auth: 'public',
	params: z.void().optional(),
	result: z
		.object({
			ping_id: Uuid,
		})
		.strict(),
} satisfies Action_Spec;

export const load_session_action_spec = {
	method: 'load_session',
	kind: 'request_response',
	operation: 'query',
	auth: 'public',
	params: z.void().optional(),
	result: z
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
} satisfies Action_Spec;

export const filer_change_action_spec = {
	method: 'filer_change',
	kind: 'remote_notification',
	operation: null,
	params: z
		.object({
			change: Diskfile_Change,
			source_file: Serializable_Source_File,
		})
		.strict(),
} satisfies Action_Spec;

export const update_diskfile_action_spec = {
	method: 'update_diskfile',
	kind: 'request_response',
	operation: 'command',
	auth: 'public',
	params: z
		.object({
			path: Diskfile_Path,
			content: z.string(),
		})
		.strict(),
	result: z.null().optional(), // TODO @many should these be void+optional?
} satisfies Action_Spec;

export const delete_diskfile_action_spec = {
	method: 'delete_diskfile',
	kind: 'request_response',
	operation: 'command',
	auth: 'public',
	params: z
		.object({
			path: Diskfile_Path,
		})
		.strict(),
	result: z.null().optional(), // TODO @many should these be void+optional?
} satisfies Action_Spec;

export const create_directory_action_spec = {
	method: 'create_directory',
	kind: 'request_response',
	operation: 'command',
	auth: 'public',
	params: z
		.object({
			path: Diskfile_Path,
		})
		.strict(),
	result: z.null().optional(), // TODO @many should these be void+optional?
} satisfies Action_Spec;

export const submit_completion_action_spec = {
	method: 'submit_completion',
	kind: 'request_response',
	operation: 'command',
	auth: 'public',
	params: z
		.object({
			completion_request: Completion_Request,
		})
		.strict(),
	result: z
		.object({
			completion_response: Completion_Response,
		})
		.strict(),
} satisfies Action_Spec;

export const toggle_main_menu_action_spec = {
	method: 'toggle_main_menu',
	kind: 'local_call',
	operation: 'command',
	params: z.union([z.boolean(), z.void()]).optional(),
	returns: Type_Literal.parse('boolean'),
} satisfies Action_Spec;
