import {z} from 'zod';

import {Diskfile_Change_Type, Source_File, Diskfile_Path, Zzz_Dir} from '$lib/diskfile_types.js';
import {Datetime_Now, get_datetime_now, Uuid, Uuid_With_Default} from '$lib/zod_helpers.js';
import {Provider_Name} from '$lib/provider_types.js';
import {Cell_Json} from '$lib/cell_types.js';

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

// Define schema for tape history action
export const Action_Tape_History = z.object({
	role: z.enum(['user', 'system', 'assistant']),
	content: z.string(),
});
export type Action_Tape_History = z.infer<typeof Action_Tape_History>;

// TODO these types need work
// Define explicit interfaces for provider-specific data
export interface Provider_Data_Ollama {
	type: 'ollama';
	value: any; // ChatResponse from ollama - must be required
}

export interface Provider_Data_Claude {
	type: 'claude';
	value: any; // Action from Anthropic - must be required
}

export interface Provider_Data_Chatgpt {
	type: 'chatgpt';
	value: any; // ChatCompletion from OpenAI - must be required
}

export interface Provider_Data_Gemini {
	type: 'gemini';
	value: {
		text: string;
		candidates: Array<any> | null;
		function_calls: Array<any> | null;
		prompt_feedback: any | null; // eslint-disable-line @typescript-eslint/no-redundant-type-constituents
		usage_metadata: any | null; // eslint-disable-line @typescript-eslint/no-redundant-type-constituents
	};
}

// Union type of all provider data types
export type Provider_Data =
	| Provider_Data_Ollama
	| Provider_Data_Claude
	| Provider_Data_Chatgpt
	| Provider_Data_Gemini;

// Schema validation for provider data
export const Provider_Data_Schema = z.discriminatedUnion('type', [
	z.object({
		type: z.literal('ollama').default('ollama'),
		value: z
			.any()
			.optional()
			.transform((v) => v || {}), // Ensure value exists even if undefined
	}),
	z.object({
		type: z.literal('claude').default('claude'),
		value: z
			.any()
			.optional()
			.transform((v) => v || {}),
	}),
	z.object({
		type: z.literal('chatgpt').default('chatgpt'),
		value: z
			.any()
			.optional()
			.transform((v) => v || {}),
	}),
	z.object({
		type: z.literal('gemini').default('gemini'),
		value: z.object({
			text: z.string(),
			candidates: z.array(z.any()).nullable().optional(),
			function_calls: z.array(z.any()).nullable().optional(),
			prompt_feedback: z.any().nullable().optional(),
			usage_metadata: z.any().nullable().optional(),
		}),
	}),
]);

// Define Completion Request and Response schemas
export const Completion_Request = z.object({
	created: Datetime_Now,
	request_id: Uuid_With_Default,
	provider_name: Provider_Name,
	model: z.string(),
	prompt: z.string(),
	tape_history: z.array(Action_Tape_History).optional(),
});
export type Completion_Request = z.infer<typeof Completion_Request>;

export const Completion_Response = z.object({
	created: Datetime_Now,
	request_id: Uuid_With_Default,
	provider_name: Provider_Name,
	model: z.string(),
	data: Provider_Data_Schema,
});
export type Completion_Response = z.infer<typeof Completion_Response>;

// Base action schema
export const Action_Base = z
	.object({
		id: Uuid_With_Default,
		type: Action_Type,
	})
	.strict();
export type Action_Base = z.infer<typeof Action_Base>;

// Ping/Pong action schemas
export const Action_Ping = Action_Base.extend({
	type: z.literal('ping').default('ping'),
}).strict();
export type Action_Ping = z.infer<typeof Action_Ping>;

export const Action_Pong = Action_Base.extend({
	type: z.literal('pong').default('pong'),
	ping_id: Uuid_With_Default,
}).strict();
export type Action_Pong = z.infer<typeof Action_Pong>;

// Session related action schemas
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

// Define schema for diskfile change
export const Diskfile_Change = z
	.object({
		type: Diskfile_Change_Type,
		path: Diskfile_Path,
	})
	.strict();
export type Diskfile_Change = z.infer<typeof Diskfile_Change>;

// File related action schemas
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

// Completion related action schemas
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

// Union of all client action types
export const Action_Client = z.discriminatedUnion('type', [
	Action_Ping,
	Action_Load_Session,
	Action_Send_Prompt,
	Action_Update_Diskfile,
	Action_Delete_Diskfile,
	Action_Create_Directory,
]);
export type Action_Client = z.infer<typeof Action_Client>;

// Union of all server action types
export const Action_Server = z.discriminatedUnion('type', [
	Action_Pong,
	Action_Loaded_Session,
	Action_Filer_Change,
	Action_Completion_Response,
]);
export type Action_Server = z.infer<typeof Action_Server>;

// Union of all action types
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

// Action with metadata schema
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

// Helper function to create a action with json representation
export const create_action_json = (action: Action, direction: Action_Direction): Action_Json => {
	return {
		...action,
		direction,
		created: get_datetime_now(),
	} as Action_Json;
};
