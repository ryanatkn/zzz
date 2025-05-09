import {z} from 'zod';

import type {Action_Spec, Service_Action_Spec, Client_Action_Spec} from '$lib/action_spec.js';
import {Diskfile_Change, Diskfile_Path, Source_File, Zzz_Dir} from '$lib/diskfile_types.js';
import {Uuid} from '$lib/zod_helpers.js';
// TODO BLOCK circular dependency
// import {Completion_Request, Completion_Response} from '$lib/tape_types.js';

const Completion_Request = {} as any;
const Completion_Response = {} as any;

/**
 * Centralized definitions for all action specifications.
 * This file serves as the single source of truth for action specifications.
 */

// Define all action specifications with proper typing
export const ping_action_spec = {
	method: 'ping',
	direction: 'client',
	type: 'Service_Action',
	http_method: 'GET',
	auth: null,
	params: z.null(),
	response: z.null(),
	returns: 'Api_Result<typeof ping_action_spec.response>', // TODO `Ping_Action_Response`
} satisfies Service_Action_Spec;

export const pong_action_spec = {
	method: 'pong',
	direction: 'server',
	type: 'Service_Action',
	http_method: null,
	auth: null,
	params: z
		.object({
			ping_id: Uuid,
		})
		.strict(),
	response: z.null(),
	returns: 'Api_Result<typeof pong_action_spec.response>', // TODO @many maybe add type aliases - `Action.Pong.Response` or `Pong_Action_Response`
} satisfies Service_Action_Spec;

export const load_session_action_spec = {
	method: 'load_session',
	direction: 'client',
	type: 'Service_Action',
	http_method: 'GET',
	auth: null,
	// TODO rethink these for actions as a whole,
	// `loaded_session_action_spec` needs to be rolled into this one
	// and the `response` here is the `params` currently there
	params: z.null(),
	response: z.null(),
	returns: 'Api_Result<typeof load_session_action_spec.response>', // TODO @many maybe add type aliases - `Action.Load_Session.Response` or `Load_Session_Action_Response`
} satisfies Service_Action_Spec;

export const loaded_session_action_spec = {
	method: 'loaded_session',
	direction: 'server',
	type: 'Service_Action',
	http_method: null,
	auth: null,
	params: z
		.object({
			data: z
				.object({
					zzz_dir: Zzz_Dir,
					files: z.array(Source_File),
				})
				.strict(),
		})
		.strict(),
	response: z.null(),
	returns: 'Api_Result<typeof loaded_session_action_spec.response>', // TODO @many maybe add type aliases - `Action.Loaded_Session.Response` or `Loaded_Session_Action_Response`
} satisfies Service_Action_Spec;

export const filer_change_action_spec = {
	method: 'filer_change',
	direction: 'server',
	type: 'Service_Action',
	http_method: null,
	auth: null,
	params: z
		.object({
			change: Diskfile_Change,
			source_file: Source_File,
		})
		.strict(),
	response: z.null(),
	returns: 'Api_Result<typeof filer_change_action_spec.response>', // TODO @many maybe add type aliases - `Action.Filer_Change.Response` or `Filer_Change_Action_Response`
} satisfies Service_Action_Spec;

export const update_diskfile_action_spec = {
	method: 'update_diskfile',
	direction: 'client',
	type: 'Client_Action',
	params: z
		.object({
			path: Diskfile_Path,
			content: z.string(),
		})
		.strict(),
	returns: 'string',
} satisfies Client_Action_Spec;

export const delete_diskfile_action_spec = {
	method: 'delete_diskfile',
	direction: 'client',
	type: 'Client_Action',
	params: z
		.object({
			path: Diskfile_Path,
		})
		.strict(),
	returns: 'string',
} satisfies Client_Action_Spec;

export const create_directory_action_spec = {
	method: 'create_directory',
	direction: 'client',
	type: 'Client_Action',
	params: z
		.object({
			path: Diskfile_Path,
		})
		.strict(),
	returns: 'string',
} satisfies Client_Action_Spec;

export const send_prompt_action_spec = {
	method: 'send_prompt',
	direction: 'client',
	type: 'Client_Action',
	params: z
		.object({
			completion_request: Completion_Request,
		})
		.strict(),
	returns: 'string',
} satisfies Client_Action_Spec;

export const completion_response_action_spec = {
	method: 'completion_response',
	direction: 'server',
	type: 'Service_Action',
	http_method: 'GET',
	auth: null,
	params: z
		.object({
			completion_response: Completion_Response,
		})
		.strict(),
	response: z.null(),
	returns: 'Api_Result<typeof completion_response_action_spec.response>', // TODO @many maybe add type aliases - `Action.Completion_Response.Response` or `Completion_Response_Action_Response`
} satisfies Service_Action_Spec;

// TODO BLOCK generate programmatically

// Collect all action specs in an array for registry population
export const action_specs: Array<Action_Spec> = [
	ping_action_spec,
	pong_action_spec,
	load_session_action_spec,
	loaded_session_action_spec,
	filer_change_action_spec,
	update_diskfile_action_spec,
	delete_diskfile_action_spec,
	create_directory_action_spec,
	send_prompt_action_spec,
	completion_response_action_spec,
];
