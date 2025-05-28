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

// Specs are the source of truth for many things including generated code -
// the goal is to make the system extensible for users but it's not there yet.

export const ping_action_spec = {
	method: 'ping',
	kind: 'request_response',
	http_method: 'GET',
	auth: 'public',
	params: z.void().optional(),
	response_params: z
		.object({
			ping_id: Uuid,
		})
		.strict(),
} satisfies Action_Spec;

export const load_session_action_spec = {
	method: 'load_session',
	kind: 'request_response',
	http_method: 'GET',
	auth: 'public',
	params: z.void().optional(),
	response_params: z
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
	kind: 'server_notification',
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
	http_method: 'POST',
	auth: 'public',
	params: z
		.object({
			path: Diskfile_Path,
			content: z.string(),
		})
		.strict(),
	response_params: z.null().optional(), // TODO @many should these be void+optional?
} satisfies Action_Spec;

export const delete_diskfile_action_spec = {
	method: 'delete_diskfile',
	kind: 'request_response',
	http_method: 'POST',
	auth: 'public',
	params: z
		.object({
			path: Diskfile_Path,
		})
		.strict(),
	response_params: z.null().optional(), // TODO @many should these be void+optional?
} satisfies Action_Spec;

export const create_directory_action_spec = {
	method: 'create_directory',
	kind: 'request_response',
	http_method: 'POST',
	auth: 'public',
	params: z
		.object({
			path: Diskfile_Path,
		})
		.strict(),
	response_params: z.null().optional(), // TODO @many should these be void+optional?
} satisfies Action_Spec;

export const submit_completion_action_spec = {
	method: 'submit_completion',
	kind: 'request_response',
	http_method: 'POST',
	auth: 'public',
	params: z
		.object({
			completion_request: Completion_Request,
		})
		.strict(),
	response_params: z
		.object({
			completion_response: Completion_Response,
		})
		.strict(),
} satisfies Action_Spec;

export const toggle_main_menu_action_spec = {
	method: 'toggle_main_menu',
	kind: 'client_local',
	params: z.union([z.boolean(), z.void()]).optional(),
	returns: Type_Literal.parse('boolean'),
} satisfies Action_Spec;
