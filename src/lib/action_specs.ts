// @slop Claude Opus 4

import {z} from 'zod';

import {
	DiskfileChange,
	DiskfileDirectoryPath,
	DiskfilePath,
	SerializableDisknode,
} from '$lib/diskfile_types.js';
import {ProviderStatus, ProviderName} from '$lib/provider_types.js';
import {CompletionMessage, CompletionRequest, CompletionResponse} from '$lib/completion_types.js';
import type {ActionSpecUnion} from '$lib/action_spec.js';
import {JsonrpcRequestId} from '$lib/jsonrpc.js';
import {
	OllamaListRequest,
	OllamaListResponse,
	OllamaPsRequest,
	OllamaPsResponse,
	OllamaShowRequest,
	OllamaShowResponse,
	OllamaPullRequest,
	OllamaDeleteRequest,
	OllamaCopyRequest,
	OllamaCreateRequest,
	OllamaProgressResponse,
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
		ping_id: JsonrpcRequestId,
	}),
	async: true,
} satisfies ActionSpecUnion;

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
			zzz_cache_dir: DiskfileDirectoryPath,
			files: z.array(SerializableDisknode),
			provider_status: z.array(ProviderStatus),
		}),
	}),
	async: true,
} satisfies ActionSpecUnion;

export const filer_change_action_spec = {
	method: 'filer_change',
	kind: 'remote_notification',
	initiator: 'backend',
	auth: null,
	side_effects: true,
	input: z.strictObject({
		change: DiskfileChange,
		disknode: SerializableDisknode,
	}),
	output: z.void(),
	async: true,
} satisfies ActionSpecUnion;

export const diskfile_update_action_spec = {
	method: 'diskfile_update',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z.strictObject({
		path: DiskfilePath,
		content: z.string(),
	}),
	output: z.null(),
	async: true,
} satisfies ActionSpecUnion;

export const diskfile_delete_action_spec = {
	method: 'diskfile_delete',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z.strictObject({
		path: DiskfilePath,
	}),
	output: z.null(),
	async: true,
} satisfies ActionSpecUnion;

export const directory_create_action_spec = {
	method: 'directory_create',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z.strictObject({
		path: DiskfilePath,
	}),
	output: z.null(),
	async: true,
} satisfies ActionSpecUnion;

export const completion_create_action_spec = {
	method: 'completion_create',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z.strictObject({
		completion_request: CompletionRequest,
		_meta: z.looseObject({progressToken: Uuid.optional()}).optional(),
	}),
	output: z.strictObject({
		completion_response: CompletionResponse,
		_meta: z.looseObject({progressToken: Uuid.optional()}).optional(),
	}),
	async: true,
} satisfies ActionSpecUnion;

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
				message: CompletionMessage.optional(),
			})
			.optional(),
		_meta: z.looseObject({progressToken: Uuid.optional()}).optional(),
	}),
	output: z.void(),
	async: true,
} satisfies ActionSpecUnion;

export const ollama_progress_action_spec = {
	method: 'ollama_progress',
	kind: 'remote_notification',
	initiator: 'backend',
	auth: null,
	side_effects: true,
	input: z.strictObject(
		OllamaProgressResponse.extend({
			_meta: z.looseObject({progressToken: Uuid.optional()}).optional(),
		}).shape,
	),
	output: z.void(),
	async: true,
} satisfies ActionSpecUnion;

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
} satisfies ActionSpecUnion;

export const ollama_list_action_spec = {
	method: 'ollama_list',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: null,
	input: OllamaListRequest,
	output: z.union([OllamaListResponse, z.null()]),
	async: true,
} satisfies ActionSpecUnion;

export const ollama_ps_action_spec = {
	method: 'ollama_ps',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: null,
	input: OllamaPsRequest,
	output: z.union([OllamaPsResponse, z.null()]),
	async: true,
} satisfies ActionSpecUnion;

export const ollama_show_action_spec = {
	method: 'ollama_show',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: null,
	input: OllamaShowRequest,
	output: z.union([OllamaShowResponse, z.null()]),
	async: true,
} satisfies ActionSpecUnion;

export const ollama_pull_action_spec = {
	method: 'ollama_pull',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z.strictObject(
		OllamaPullRequest.extend({
			_meta: z.looseObject({progressToken: Uuid.optional()}).optional(),
		}).shape,
	), // TODO @many is strict right here?
	output: z.void().optional(),
	async: true,
} satisfies ActionSpecUnion;

export const ollama_delete_action_spec = {
	method: 'ollama_delete',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: OllamaDeleteRequest,
	output: z.void().optional(),
	async: true,
} satisfies ActionSpecUnion;

export const ollama_copy_action_spec = {
	method: 'ollama_copy',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: OllamaCopyRequest,
	output: z.void().optional(),
	async: true,
} satisfies ActionSpecUnion;

export const ollama_create_action_spec = {
	method: 'ollama_create',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z.strictObject(
		OllamaCreateRequest.extend({
			_meta: z.looseObject({progressToken: Uuid.optional()}).optional(),
		}).shape,
	), // TODO @many is strict right here?
	output: z.void().optional(),
	async: true,
} satisfies ActionSpecUnion;

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
} satisfies ActionSpecUnion;

export const provider_load_status_action_spec = {
	method: 'provider_load_status',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: null,
	input: z.strictObject({
		provider_name: ProviderName,
		reload: z.boolean().default(true).optional(),
	}),
	output: z.strictObject({
		status: ProviderStatus,
	}),
	async: true,
} satisfies ActionSpecUnion;

export const provider_update_api_key_action_spec = {
	method: 'provider_update_api_key',
	kind: 'request_response',
	initiator: 'frontend',
	auth: 'public',
	side_effects: true,
	input: z.strictObject({
		provider_name: ProviderName,
		api_key: z.string(),
	}),
	output: z.strictObject({
		status: ProviderStatus,
	}),
	async: true,
} satisfies ActionSpecUnion;
