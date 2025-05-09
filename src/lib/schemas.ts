import {z} from 'zod';

import {Source_File, Diskfile_Path, Zzz_Dir, Diskfile_Change} from '$lib/diskfile_types.js';
import {Datetime_Now, Uuid, Uuid_With_Default} from '$lib/zod_helpers.js';
import {Provider_Name} from '$lib/provider_types.js';
import type {Http_Method} from '$lib/api.js';
import {Action_Name} from '$lib/action_types.js';

// Action types and schemas following Model Context Protocol patterns

export const Action_Direction = z.enum(['client', 'server', 'both']);
export type Action_Direction = z.infer<typeof Action_Direction>;

export const Tape_Role = z.enum(['user', 'system', 'assistant']);
export type Tape_Role = z.infer<typeof Tape_Role>;

export const Tape_Message = z.object({
	role: Tape_Role,
	content: z.string(),
});
export type Tape_Message = z.infer<typeof Tape_Message>;

// Provider-specific data schemas
export const Provider_Data_Ollama = z.object({
	type: z.literal('ollama'),
	value: z.any().optional().default({}),
});
export type Provider_Data_Ollama = z.infer<typeof Provider_Data_Ollama>;

export const Provider_Data_Claude = z.object({
	type: z.literal('claude'),
	value: z.any().optional().default({}),
});
export type Provider_Data_Claude = z.infer<typeof Provider_Data_Claude>;

export const Provider_Data_Chatgpt = z.object({
	type: z.literal('chatgpt'),
	value: z.any().optional().default({}),
});
export type Provider_Data_Chatgpt = z.infer<typeof Provider_Data_Chatgpt>;

export const Provider_Data_Gemini = z.object({
	type: z.literal('gemini'),
	value: z.object({
		text: z.string(),
		candidates: z.array(z.any()).nullable().optional(),
		function_calls: z.array(z.any()).nullable().optional(),
		prompt_feedback: z.any().nullable().optional(),
		usage_metadata: z.any().nullable().optional(),
	}),
});
export type Provider_Data_Gemini = z.infer<typeof Provider_Data_Gemini>;

export const Provider_Data_Schema = z.discriminatedUnion('type', [
	Provider_Data_Ollama,
	Provider_Data_Claude,
	Provider_Data_Chatgpt,
	Provider_Data_Gemini,
]);
export type Provider_Data = z.infer<typeof Provider_Data_Schema>;

// Request and response schemas
export const Completion_Request = z
	.object({
		created: Datetime_Now,
		request_id: Uuid_With_Default,
		provider_name: Provider_Name,
		model: z.string(),
		prompt: z.string(),
		tape_messages: z.array(Tape_Message).optional(),
	})
	.strict();
export type Completion_Request = z.infer<typeof Completion_Request>;

export const Completion_Response = z
	.object({
		created: Datetime_Now,
		request_id: Uuid_With_Default,
		provider_name: Provider_Name,
		model: z.string(),
		data: Provider_Data_Schema,
	})
	.strict();
export type Completion_Response = z.infer<typeof Completion_Response>;

// Base action schema with common properties
export const Action_Base = z
	.object({
		id: Uuid_With_Default,
		created: Datetime_Now,
		name: Action_Name,
	})
	.strict();
export type Action_Base = z.infer<typeof Action_Base>;

export const Action_Spec_Base_Schema = z.object({
	name: Action_Name,
	params: z.instanceof(z.ZodType),
	returns: z.string(),
});
export type Action_Spec_Base = z.infer<typeof Action_Spec_Base_Schema>;

export const Client_Action_Spec = Action_Spec_Base_Schema.extend({
	type: z.literal('Client_Action'),
});
export type Client_Action_Spec = z.infer<typeof Client_Action_Spec>;

export const Service_Action_Spec = Action_Spec_Base_Schema.extend({
	type: z.literal('Service_Action'),
	method: z.union([z.custom<Http_Method>(), z.null()]),
	auth: z.union([z.literal('authenticate'), z.literal('authorize'), z.null()]),
	response: z.instanceof(z.ZodType),
	// TODO some things like cant/shouldnt be done over websockets,
	// e.g. login/logout for cookies, but then maybe cookies should be the declarative property?
	// websockets: z.boolean().optional().default(false),
});
export type Service_Action_Spec = z.infer<typeof Service_Action_Spec>;

export const Action_Spec = z.union([Client_Action_Spec, Service_Action_Spec]);
export type Action_Spec = z.infer<typeof Action_Spec>;

// TODO BLOCK I think `Action_Message` is the right name here? So `Ping_Action_Message`, and then the specs have a new `message` property
export const Action_Ping = Action_Base.extend({
	name: z.literal('ping').default('ping'),
}).strict();
export type Action_Ping = z.infer<typeof Action_Ping>;

export const Action_Pong = Action_Base.extend({
	name: z.literal('pong').default('pong'),
	ping_id: Uuid_With_Default,
}).strict();
export type Action_Pong = z.infer<typeof Action_Pong>;

export const Action_Load_Session = Action_Base.extend({
	name: z.literal('load_session').default('load_session'),
}).strict();
export type Action_Load_Session = z.infer<typeof Action_Load_Session>;

export const Action_Loaded_Session = Action_Base.extend({
	name: z.literal('loaded_session').default('loaded_session'),
	data: z
		.object({
			zzz_dir: Zzz_Dir,
			files: z.array(Source_File),
		})
		.strict(),
}).strict();
export type Action_Loaded_Session = z.infer<typeof Action_Loaded_Session>;

export const Action_Filer_Change = Action_Base.extend({
	name: z.literal('filer_change').default('filer_change'),
	change: Diskfile_Change,
	source_file: Source_File,
}).strict();
export type Action_Filer_Change = z.infer<typeof Action_Filer_Change>;

export const Action_Update_Diskfile = Action_Base.extend({
	name: z.literal('update_diskfile').default('update_diskfile'),
	path: Diskfile_Path,
	content: z.string(),
}).strict();
export type Action_Update_Diskfile = z.infer<typeof Action_Update_Diskfile>;

export const Action_Delete_Diskfile = Action_Base.extend({
	name: z.literal('delete_diskfile').default('delete_diskfile'),
	path: Diskfile_Path,
}).strict();
export type Action_Delete_Diskfile = z.infer<typeof Action_Delete_Diskfile>;

export const Action_Create_Directory = Action_Base.extend({
	name: z.literal('create_directory').default('create_directory'),
	path: Diskfile_Path,
}).strict();
export type Action_Create_Directory = z.infer<typeof Action_Create_Directory>;

export const Action_Send_Prompt = Action_Base.extend({
	name: z.literal('send_prompt').default('send_prompt'),
	completion_request: Completion_Request,
}).strict();
export type Action_Send_Prompt = z.infer<typeof Action_Send_Prompt>;

export const Action_Completion_Response = Action_Base.extend({
	name: z.literal('completion_response').default('completion_response'),
	completion_response: Completion_Response,
}).strict();
export type Action_Completion_Response = z.infer<typeof Action_Completion_Response>;

// Action parameters and response schemas

export const Ping_Action_Params = z.null();
export type Ping_Action_Params = z.infer<typeof Ping_Action_Params>;

export const Ping_Action_Response = z.null();
export type Ping_Action_Response = z.infer<typeof Ping_Action_Response>;

export const Pong_Action_Params = z
	.object({
		ping_id: Uuid,
	})
	.strict();
export type Pong_Action_Params = z.infer<typeof Pong_Action_Params>;

export const Pong_Action_Response = z.null();
export type Pong_Action_Response = z.infer<typeof Pong_Action_Response>;

export const Load_Session_Action_Params = z.null();
export type Load_Session_Action_Params = z.infer<typeof Load_Session_Action_Params>;

export const Load_Session_Action_Response = z.null();
export type Load_Session_Action_Response = z.infer<typeof Load_Session_Action_Response>;

export const Loaded_Session_Action_Params = z
	.object({
		data: z
			.object({
				zzz_dir: Zzz_Dir,
				files: z.array(Source_File),
			})
			.strict(),
	})
	.strict();
export type Loaded_Session_Action_Params = z.infer<typeof Loaded_Session_Action_Params>;

export const Loaded_Session_Action_Response = z.null();
export type Loaded_Session_Action_Response = z.infer<typeof Loaded_Session_Action_Response>;

export const Filer_Change_Action_Params = z
	.object({
		change: Diskfile_Change,
		source_file: Source_File,
	})
	.strict();
export type Filer_Change_Action_Params = z.infer<typeof Filer_Change_Action_Params>;

export const Filer_Change_Action_Response = z.null();
export type Filer_Change_Action_Response = z.infer<typeof Filer_Change_Action_Response>;

export const Update_Diskfile_Action_Params = z
	.object({
		path: Diskfile_Path,
		content: z.string(),
	})
	.strict();
export type Update_Diskfile_Action_Params = z.infer<typeof Update_Diskfile_Action_Params>;

export const Delete_Diskfile_Action_Params = z
	.object({
		path: Diskfile_Path,
	})
	.strict();
export type Delete_Diskfile_Action_Params = z.infer<typeof Delete_Diskfile_Action_Params>;

export const Create_Directory_Action_Params = z
	.object({
		path: Diskfile_Path,
	})
	.strict();
export type Create_Directory_Action_Params = z.infer<typeof Create_Directory_Action_Params>;

export const Send_Prompt_Action_Params = z
	.object({
		completion_request: Completion_Request,
	})
	.strict();
export type Send_Prompt_Action_Params = z.infer<typeof Send_Prompt_Action_Params>;

export const Completion_Response_Action_Params = z
	.object({
		completion_response: Completion_Response,
	})
	.strict();
export type Completion_Response_Action_Params = z.infer<typeof Completion_Response_Action_Params>;

export const Completion_Response_Action_Response = z.null();
export type Completion_Response_Action_Response = z.infer<
	typeof Completion_Response_Action_Response
>;

export const ping_action_spec = {
	name: 'ping',
	type: 'Service_Action',
	method: 'GET',
	auth: null,
	params: Ping_Action_Params,
	response: Ping_Action_Response,
	returns: 'Api_Result<Ping_Action_Response>',
} satisfies Service_Action_Spec;

export const pong_action_spec = {
	name: 'pong',
	type: 'Service_Action',
	method: null,
	auth: null,
	params: Pong_Action_Params,
	response: Pong_Action_Response,
	returns: 'Api_Result<Pong_Action_Response>',
} satisfies Service_Action_Spec;

export const load_session_action_spec = {
	name: 'load_session',
	type: 'Service_Action',
	method: 'GET',
	auth: null,
	params: Load_Session_Action_Params,
	response: Load_Session_Action_Response,
	returns: 'Api_Result<Load_Session_Action_Response>',
} satisfies Service_Action_Spec;

export const loaded_session_action_spec = {
	name: 'loaded_session',
	type: 'Service_Action',
	method: null,
	auth: null,
	params: Loaded_Session_Action_Params,
	response: Loaded_Session_Action_Response,
	returns: 'Api_Result<Loaded_Session_Action_Response>',
} satisfies Service_Action_Spec;

export const filer_change_action_spec = {
	name: 'filer_change',
	type: 'Service_Action',
	method: null,
	auth: null,
	params: Filer_Change_Action_Params,
	response: Filer_Change_Action_Response,
	returns: 'Api_Result<Filer_Change_Action_Response>',
} satisfies Service_Action_Spec;

export const update_diskfile_action_spec = {
	name: 'update_diskfile',
	type: 'Client_Action',
	params: Update_Diskfile_Action_Params,
	returns: 'string',
} satisfies Client_Action_Spec;

export const delete_diskfile_action_spec = {
	name: 'delete_diskfile',
	type: 'Client_Action',
	params: Delete_Diskfile_Action_Params,
	returns: 'string',
} satisfies Client_Action_Spec;

export const create_directory_action_spec = {
	name: 'create_directory',
	type: 'Client_Action',
	params: Create_Directory_Action_Params,
	returns: 'string',
} satisfies Client_Action_Spec;

export const send_prompt_action_spec = {
	name: 'send_prompt',
	type: 'Client_Action',
	params: Send_Prompt_Action_Params,
	returns: 'string',
} satisfies Client_Action_Spec;

export const completion_response_action_spec = {
	name: 'completion_response',
	type: 'Service_Action',
	method: 'GET',
	auth: null,
	params: Completion_Response_Action_Params,
	response: Completion_Response_Action_Response,
	returns: 'Api_Result<Completion_Response_Action_Response>',
} satisfies Service_Action_Spec;
