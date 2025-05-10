import {z} from 'zod';

import type {Action_Spec} from '$lib/action_spec.js';
import {Diskfile_Change, Diskfile_Path, Source_File, Zzz_Dir} from '$lib/diskfile_types.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Completion_Request, Completion_Response} from '$lib/completion_types.js';

/**
 * Centralized definitions for all action specifications.
 * This file serves as the single source of truth for action specifications.
 */

// Define all action specifications with proper typing
export const ping_action_spec = {
	method: 'ping',
	type: 'request_response',
	http_method: 'GET',
	auth: null,
	params: z.void(),
	response: z
		.object({
			ping_id: Uuid,
		})
		.strict(),
	returns: 'Api_Result<typeof ping_action_spec.response>',
} satisfies Action_Spec;

export const load_session_action_spec = {
	method: 'load_session',
	type: 'request_response',
	http_method: 'GET',
	auth: null,
	params: z.void(),
	response: z
		.object({
			data: z
				.object({
					zzz_dir: Zzz_Dir,
					files: z.array(Source_File),
				})
				.strict(),
		})
		.strict(),
	returns: 'Api_Result<typeof load_session_action_spec.response>',
} satisfies Action_Spec;

export const filer_change_action_spec = {
	method: 'filer_change',
	type: 'server_notification',
	http_method: null,
	auth: null,
	params: z
		.object({
			change: Diskfile_Change,
			source_file: Source_File,
		})
		.strict(),
	response: z.null(),
	returns: 'Api_Result<typeof filer_change_action_spec.response>',
} satisfies Action_Spec;

export const update_diskfile_action_spec = {
	method: 'update_diskfile',
	type: 'request_response',
	params: z
		.object({
			path: Diskfile_Path,
			content: z.string(),
		})
		.strict(),
	response: z.null(),
	returns: 'string',
} satisfies Action_Spec;

export const delete_diskfile_action_spec = {
	method: 'delete_diskfile',
	type: 'request_response',
	params: z
		.object({
			path: Diskfile_Path,
		})
		.strict(),
	response: z.null(),
	returns: 'string',
} satisfies Action_Spec;

export const create_directory_action_spec = {
	method: 'create_directory',
	type: 'request_response',
	params: z
		.object({
			path: Diskfile_Path,
		})
		.strict(),
	response: z.null(),
	returns: 'string',
} satisfies Action_Spec;

export const send_prompt_action_spec = {
	method: 'send_prompt',
	type: 'request_response',
	http_method: 'POST',
	auth: null,
	params: z
		.object({
			completion_request: Completion_Request,
		})
		.strict(),
	response: z
		.object({
			completion_response: Completion_Response,
		})
		.strict(),
	returns: 'Api_Result<typeof send_prompt_action_spec.response>',
} satisfies Action_Spec;

export const toggle_main_menu_action_spec = {
	method: 'toggle_main_menu',
	type: 'client_local',
	params: z.void(),
	returns: 'string',
} satisfies Action_Spec;

// TODO BLOCK generate programmatically

// Collect all action specs in an array for registry population
export const action_specs: Array<Action_Spec> = [
	ping_action_spec,
	load_session_action_spec,
	filer_change_action_spec,
	update_diskfile_action_spec,
	delete_diskfile_action_spec,
	create_directory_action_spec,
	send_prompt_action_spec,
	toggle_main_menu_action_spec,
];
