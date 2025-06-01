import {z} from 'zod';

import {create_action_spec} from '$lib/action_spec.js';
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

export const ping_action_spec = create_action_spec({
	method: 'ping',
	kind: 'request_response',
	initiator: 'both',
	operation: 'query',
	auth: 'public',
	input: z.void().optional(),
	output: z
		.object({
			ping_id: Uuid,
		})
		.strict(),
});

export const load_session_action_spec = create_action_spec({
	method: 'load_session',
	kind: 'request_response',
	// TODO @api is this actually a good restriction to have?
	// or should the server be calling actions internally too?
	initiator: 'client',
	operation: 'query',
	auth: 'public',
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
});

export const filer_change_action_spec = create_action_spec({
	method: 'filer_change',
	kind: 'remote_notification',
	initiator: 'server',
	operation: null,
	auth: null,
	input: z
		.object({
			change: Diskfile_Change,
			source_file: Serializable_Source_File,
		})
		.strict(),
	output: null,
});

export const update_diskfile_action_spec = create_action_spec({
	method: 'update_diskfile',
	kind: 'request_response',
	initiator: 'client',
	operation: 'command',
	auth: 'public',
	input: z
		.object({
			path: Diskfile_Path,
			content: z.string(),
		})
		.strict(),
});

export const delete_diskfile_action_spec = create_action_spec({
	method: 'delete_diskfile',
	kind: 'request_response',
	initiator: 'client',
	operation: 'command',
	auth: 'public',
	input: z
		.object({
			path: Diskfile_Path,
		})
		.strict(),
});

export const create_directory_action_spec = create_action_spec({
	method: 'create_directory',
	kind: 'request_response',
	initiator: 'client',
	operation: 'command',
	auth: 'public',
	input: z
		.object({
			path: Diskfile_Path,
		})
		.strict(),
});

export const submit_completion_action_spec = create_action_spec({
	method: 'submit_completion',
	kind: 'request_response',
	initiator: 'client',
	operation: 'command',
	auth: 'public',
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
});

export const toggle_main_menu_action_spec = create_action_spec({
	method: 'toggle_main_menu',
	kind: 'local_call',
	initiator: 'client',
	operation: 'command',
	auth: null,
	input: z.union([z.boolean(), z.void()]).optional(),
	output: null,
	returns: Type_Literal.parse('boolean'),
});
