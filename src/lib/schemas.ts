import {z} from 'zod';

import {Diskfile_Change_Type, Source_File, Diskfile_Path, Zzz_Dir} from '$lib/diskfile_types.js';
import {Datetime_Now, get_datetime_now, Uuid, Uuid_With_Default} from '$lib/zod_helpers.js';
import {Provider_Name} from '$lib/provider_types.js';
import {Cell_Json} from '$lib/cell_types.js';

// Action types and schemas following Model Context Protocol patterns

export const Action_Direction = z.enum(['client', 'server', 'both']);
export type Action_Direction = z.infer<typeof Action_Direction>;

export const Action_Type = z.enum([
	'ping',
	'pong',
	'load_session',
	'loaded_session',
	'send_prompt',
	'completion_response',
	'filer_change',
	'update_diskfile',
	'delete_diskfile',
	'create_directory',
]);
export type Action_Type = z.infer<typeof Action_Type>;

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
		type: Action_Type,
	})
	.strict();
export type Action_Base = z.infer<typeof Action_Base>;

// Diskfile change schema
export const Diskfile_Change = z
	.object({
		type: Diskfile_Change_Type,
		path: Diskfile_Path,
	})
	.strict();
export type Diskfile_Change = z.infer<typeof Diskfile_Change>;

/**
 * Base schema for all action schemas
 */
export interface Action_Schema_Base {
	name: string;
	params: z.ZodTypeAny;
	returns: string;
}

/**
 * Schema for client-only actions
 */
export interface Client_Action_Schema extends Action_Schema_Base {
	type: 'Client_Action';
}

/**
 * Schema for service actions that can be called from client or server
 */
export interface Service_Action_Schema extends Action_Schema_Base {
	type: 'Service_Action';
	auth: null | 'authenticate' | 'authorize';
	websockets: boolean;
	broadcast: boolean;
	response: z.ZodTypeAny;
}

/**
 * Union type of all action schemas
 */
export type Action_Schema = Client_Action_Schema | Service_Action_Schema;

/**
 * Type for action schema names
 */
export type Action_Schema_Name = string;

// Parameter and Response types for Actions

// Ping
export const Action_Ping_Params = z.null();
export type Action_Ping_Params = z.infer<typeof Action_Ping_Params>;

export const Action_Ping_Response = z.null();
export type Action_Ping_Response = z.infer<typeof Action_Ping_Response>;

// Pong
export const Action_Pong_Params = z
	.object({
		ping_id: Uuid,
	})
	.strict();
export type Action_Pong_Params = z.infer<typeof Action_Pong_Params>;

export const Action_Pong_Response = z.null();
export type Action_Pong_Response = z.infer<typeof Action_Pong_Response>;

// Load Session
export const Action_Load_Session_Params = z.null();
export type Action_Load_Session_Params = z.infer<typeof Action_Load_Session_Params>;

export const Action_Load_Session_Response = z.null();
export type Action_Load_Session_Response = z.infer<typeof Action_Load_Session_Response>;

// Loaded Session
export const Action_Loaded_Session_Params = z
	.object({
		data: z
			.object({
				zzz_dir: Zzz_Dir,
				files: z.array(Source_File),
			})
			.strict(),
	})
	.strict();
export type Action_Loaded_Session_Params = z.infer<typeof Action_Loaded_Session_Params>;

export const Action_Loaded_Session_Response = z.null();
export type Action_Loaded_Session_Response = z.infer<typeof Action_Loaded_Session_Response>;

// Filer Change
export const Action_Filer_Change_Params = z
	.object({
		change: Diskfile_Change,
		source_file: Source_File,
	})
	.strict();
export type Action_Filer_Change_Params = z.infer<typeof Action_Filer_Change_Params>;

export const Action_Filer_Change_Response = z.null();
export type Action_Filer_Change_Response = z.infer<typeof Action_Filer_Change_Response>;

// Update Diskfile
export const Action_Update_Diskfile_Params = z
	.object({
		path: Diskfile_Path,
		content: z.string(),
	})
	.strict();
export type Action_Update_Diskfile_Params = z.infer<typeof Action_Update_Diskfile_Params>;

// Delete Diskfile
export const Action_Delete_Diskfile_Params = z
	.object({
		path: Diskfile_Path,
	})
	.strict();
export type Action_Delete_Diskfile_Params = z.infer<typeof Action_Delete_Diskfile_Params>;

// Create Directory
export const Action_Create_Directory_Params = z
	.object({
		path: Diskfile_Path,
	})
	.strict();
export type Action_Create_Directory_Params = z.infer<typeof Action_Create_Directory_Params>;

// Send Prompt
export const Action_Send_Prompt_Params = z
	.object({
		completion_request: Completion_Request,
	})
	.strict();
export type Action_Send_Prompt_Params = z.infer<typeof Action_Send_Prompt_Params>;

// Completion Response
export const Action_Completion_Response_Params = z
	.object({
		completion_response: Completion_Response,
	})
	.strict();
export type Action_Completion_Response_Params = z.infer<typeof Action_Completion_Response_Params>;

export const Action_Completion_Response_Response = z.null();
export type Action_Completion_Response_Response = z.infer<
	typeof Action_Completion_Response_Response
>;

// Action Schema Definitions

export const Action_Ping_Schema: Service_Action_Schema = {
	type: 'Service_Action',
	name: 'Action_Ping',
	auth: null,
	websockets: true,
	broadcast: false,
	params: Action_Ping_Params,
	response: Action_Ping_Response,
	returns: 'Api_Result<Action_Ping_Response>',
};

export const Action_Pong_Schema: Service_Action_Schema = {
	type: 'Service_Action',
	name: 'Action_Pong',
	auth: null,
	websockets: true,
	broadcast: false,
	params: Action_Pong_Params,
	response: Action_Pong_Response,
	returns: 'Api_Result<Action_Pong_Response>',
};

export const Action_Load_Session_Schema: Service_Action_Schema = {
	type: 'Service_Action',
	name: 'Action_Load_Session',
	auth: null,
	websockets: true,
	broadcast: false,
	params: Action_Load_Session_Params,
	response: Action_Load_Session_Response,
	returns: 'Api_Result<Action_Load_Session_Response>',
};

export const Action_Loaded_Session_Schema: Service_Action_Schema = {
	type: 'Service_Action',
	name: 'Action_Loaded_Session',
	auth: null,
	websockets: true,
	broadcast: false,
	params: Action_Loaded_Session_Params,
	response: Action_Loaded_Session_Response,
	returns: 'Api_Result<Action_Loaded_Session_Response>',
};

export const Action_Filer_Change_Schema: Service_Action_Schema = {
	type: 'Service_Action',
	name: 'Action_Filer_Change',
	auth: null,
	websockets: true,
	broadcast: true,
	params: Action_Filer_Change_Params,
	response: Action_Filer_Change_Response,
	returns: 'Api_Result<Action_Filer_Change_Response>',
};

export const Action_Update_Diskfile_Schema: Client_Action_Schema = {
	type: 'Client_Action',
	name: 'Action_Update_Diskfile',
	params: Action_Update_Diskfile_Params,
	returns: 'string',
};

export const Action_Delete_Diskfile_Schema: Client_Action_Schema = {
	type: 'Client_Action',
	name: 'Action_Delete_Diskfile',
	params: Action_Delete_Diskfile_Params,
	returns: 'string',
};

export const Action_Create_Directory_Schema: Client_Action_Schema = {
	type: 'Client_Action',
	name: 'Action_Create_Directory',
	params: Action_Create_Directory_Params,
	returns: 'string',
};

export const Action_Send_Prompt_Schema: Client_Action_Schema = {
	type: 'Client_Action',
	name: 'Action_Send_Prompt',
	params: Action_Send_Prompt_Params,
	returns: 'string',
};

export const Action_Completion_Response_Schema: Service_Action_Schema = {
	type: 'Service_Action',
	name: 'Action_Completion_Response',
	auth: null,
	websockets: true,
	broadcast: false,
	params: Action_Completion_Response_Params,
	response: Action_Completion_Response_Response,
	returns: 'Api_Result<Action_Completion_Response_Response>',
};

// Concrete action types
export const Action_Ping = Action_Base.extend({
	type: z.literal('ping').default('ping'),
}).strict();
export type Action_Ping = z.infer<typeof Action_Ping>;

export const Action_Pong = Action_Base.extend({
	type: z.literal('pong').default('pong'),
	ping_id: Uuid_With_Default,
}).strict();
export type Action_Pong = z.infer<typeof Action_Pong>;

export const Action_Load_Session = Action_Base.extend({
	type: z.literal('load_session').default('load_session'),
}).strict();
export type Action_Load_Session = z.infer<typeof Action_Load_Session>;

export const Action_Loaded_Session = Action_Base.extend({
	type: z.literal('loaded_session').default('loaded_session'),
	data: z
		.object({
			zzz_dir: Zzz_Dir,
			files: z.array(Source_File),
		})
		.strict(),
}).strict();
export type Action_Loaded_Session = z.infer<typeof Action_Loaded_Session>;

export const Action_Filer_Change = Action_Base.extend({
	type: z.literal('filer_change').default('filer_change'),
	change: Diskfile_Change,
	source_file: Source_File,
}).strict();
export type Action_Filer_Change = z.infer<typeof Action_Filer_Change>;

export const Action_Update_Diskfile = Action_Base.extend({
	type: z.literal('update_diskfile').default('update_diskfile'),
	path: Diskfile_Path,
	content: z.string(),
}).strict();
export type Action_Update_Diskfile = z.infer<typeof Action_Update_Diskfile>;

export const Action_Delete_Diskfile = Action_Base.extend({
	type: z.literal('delete_diskfile').default('delete_diskfile'),
	path: Diskfile_Path,
}).strict();
export type Action_Delete_Diskfile = z.infer<typeof Action_Delete_Diskfile>;

export const Action_Create_Directory = Action_Base.extend({
	type: z.literal('create_directory').default('create_directory'),
	path: Diskfile_Path,
}).strict();
export type Action_Create_Directory = z.infer<typeof Action_Create_Directory>;

export const Action_Send_Prompt = Action_Base.extend({
	type: z.literal('send_prompt').default('send_prompt'),
	completion_request: Completion_Request,
}).strict();
export type Action_Send_Prompt = z.infer<typeof Action_Send_Prompt>;

export const Action_Completion_Response = Action_Base.extend({
	type: z.literal('completion_response').default('completion_response'),
	completion_response: Completion_Response,
}).strict();
export type Action_Completion_Response = z.infer<typeof Action_Completion_Response>;

// Action unions by direction
export const Action_Client = z.discriminatedUnion('type', [
	Action_Ping,
	Action_Load_Session,
	Action_Send_Prompt,
	Action_Update_Diskfile,
	Action_Delete_Diskfile,
	Action_Create_Directory,
]);
export type Action_Client = z.infer<typeof Action_Client>;

export const Action_Server = z.discriminatedUnion('type', [
	Action_Pong,
	Action_Loaded_Session,
	Action_Filer_Change,
	Action_Completion_Response,
]);
export type Action_Server = z.infer<typeof Action_Server>;

export const Action = z.discriminatedUnion('type', [
	Action_Ping,
	Action_Pong,
	Action_Load_Session,
	Action_Loaded_Session,
	Action_Filer_Change,
	Action_Send_Prompt,
	Action_Completion_Response,
	Action_Update_Diskfile,
	Action_Delete_Diskfile,
	Action_Create_Directory,
]);
export type Action = z.infer<typeof Action>;

// Mapping for action directions
export const action_directions: Record<string, Action_Direction> = {
	ping: 'client',
	pong: 'server',
	load_session: 'client',
	loaded_session: 'server',
	send_prompt: 'client',
	completion_response: 'server',
	filer_change: 'server',
	update_diskfile: 'client',
	delete_diskfile: 'client',
	create_directory: 'client',
};

export const Action_Json = Cell_Json.extend({
	type: Action_Type,
	direction: Action_Direction,
	// Optional fields with proper type checking
	ping_id: Uuid.optional(),
	completion_request: Completion_Request.optional(),
	completion_response: Completion_Response.optional(),
	path: Diskfile_Path.optional(),
	content: z.string().optional(),
	change: Diskfile_Change.optional(),
	source_file: Source_File.optional(),
	data: z.record(z.string(), z.any()).optional(),
}).strict();
export type Action_Json = z.infer<typeof Action_Json>;
export type Action_Json_Input = z.input<typeof Action_Json>;

// Helper function to create an action with json representation
export const create_action_json = (action: Action, direction: Action_Direction): Action_Json => {
	return {
		...action,
		direction,
		created: get_datetime_now(),
	} as Action_Json;
};

// Helper to get the direction for an action
export const get_action_direction = (type: Action_Type): Action_Direction => {
	return action_directions[type];
};

// Export the action schemas for registration
export const action_schemas_registry: Array<Action_Schema> = [
	Action_Ping_Schema,
	Action_Pong_Schema,
	Action_Load_Session_Schema,
	Action_Loaded_Session_Schema,
	Action_Filer_Change_Schema,
	Action_Update_Diskfile_Schema,
	Action_Delete_Diskfile_Schema,
	Action_Create_Directory_Schema,
	Action_Send_Prompt_Schema,
	Action_Completion_Response_Schema,
];
