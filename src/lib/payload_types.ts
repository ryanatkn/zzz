import {z} from 'zod';

import {Diskfile_Change_Type, Source_File, Diskfile_Path, Zzz_Dir} from '$lib/diskfile_types.js';
import {Datetime_Now, Uuid} from '$lib/zod_helpers.js';
import {Provider_Name} from '$lib/provider_types.js';
import {Cell_Json} from '$lib/cell_types.js';

export const Payload_Direction = z.enum(['client', 'server', 'both']);
export type Payload_Direction = z.infer<typeof Payload_Direction>;

export const Payload_Type = z.enum([
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
export type Payload_Type = z.infer<typeof Payload_Type>;

// Define schema for tape history payload
export const Payload_Tape_History = z.object({
	role: z.enum(['user', 'system', 'assistant']),
	content: z.string(),
});
export type Payload_Tape_History = z.infer<typeof Payload_Tape_History>;

// TODO these types need work
// Define explicit interfaces for provider-specific data
export interface Provider_Data_Ollama {
	type: 'ollama';
	value: any; // ChatResponse from ollama - must be required
}

export interface Provider_Data_Claude {
	type: 'claude';
	value: any; // Payload from Anthropic - must be required
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
	request_id: Uuid,
	provider_name: Provider_Name,
	model: z.string(),
	prompt: z.string(),
	tape_history: z.array(Payload_Tape_History).optional(),
});
export type Completion_Request = z.infer<typeof Completion_Request>;

export const Completion_Response = z.object({
	created: Datetime_Now,
	request_id: Uuid,
	provider_name: Provider_Name,
	model: z.string(),
	data: Provider_Data_Schema,
});
export type Completion_Response = z.infer<typeof Completion_Response>;

// Base payload schema
export const Payload_Base = z
	.object({
		id: Uuid,
		type: Payload_Type,
	})
	.strict();
export type Payload_Base = z.infer<typeof Payload_Base>;

// Ping/Pong payload schemas
export const Payload_Ping = Payload_Base.extend({
	type: z.literal('ping').default('ping'),
}).strict();
export type Payload_Ping = z.infer<typeof Payload_Ping>;

export const Payload_Pong = Payload_Base.extend({
	type: z.literal('pong').default('pong'),
	ping_id: Uuid,
}).strict();
export type Payload_Pong = z.infer<typeof Payload_Pong>;

// Session related payload schemas
export const Payload_Load_Session = Payload_Base.extend({
	type: z.literal('load_session').default('load_session'),
}).strict();
export type Payload_Load_Session = z.infer<typeof Payload_Load_Session>;

export const Payload_Loaded_Session = Payload_Base.extend({
	type: z.literal('loaded_session').default('loaded_session'),
	data: z
		.object({
			zzz_dir: Zzz_Dir,
			files: z.array(Source_File),
		})
		.strict(),
}).strict();
export type Payload_Loaded_Session = z.infer<typeof Payload_Loaded_Session>;

// Define schema for diskfile change
export const Diskfile_Change = z
	.object({
		type: Diskfile_Change_Type,
		path: Diskfile_Path,
	})
	.strict();
export type Diskfile_Change = z.infer<typeof Diskfile_Change>;

// File related payload schemas
export const Payload_Filer_Change = Payload_Base.extend({
	type: z.literal('filer_change').default('filer_change'),
	change: Diskfile_Change,
	source_file: Source_File,
}).strict();
export type Payload_Filer_Change = z.infer<typeof Payload_Filer_Change>;

export const Payload_Update_Diskfile = Payload_Base.extend({
	type: z.literal('update_diskfile').default('update_diskfile'),
	path: Diskfile_Path,
	content: z.string(),
}).strict();
export type Payload_Update_Diskfile = z.infer<typeof Payload_Update_Diskfile>;

export const Payload_Delete_Diskfile = Payload_Base.extend({
	type: z.literal('delete_diskfile').default('delete_diskfile'),
	path: Diskfile_Path,
}).strict();
export type Payload_Delete_Diskfile = z.infer<typeof Payload_Delete_Diskfile>;

export const Payload_Create_Directory = Payload_Base.extend({
	type: z.literal('create_directory').default('create_directory'),
	path: Diskfile_Path,
}).strict();
export type Payload_Create_Directory = z.infer<typeof Payload_Create_Directory>;

// Completion related payload schemas
export const Payload_Send_Prompt = Payload_Base.extend({
	type: z.literal('send_prompt').default('send_prompt'),
	completion_request: Completion_Request,
}).strict();
export type Payload_Send_Prompt = z.infer<typeof Payload_Send_Prompt>;

export const Payload_Completion_Response = Payload_Base.extend({
	type: z.literal('completion_response').default('completion_response'),
	completion_response: Completion_Response,
}).strict();
export type Payload_Completion_Response = z.infer<typeof Payload_Completion_Response>;

// Union of all client payload types
export const Payload_Client = z.discriminatedUnion('type', [
	Payload_Ping,
	Payload_Load_Session,
	Payload_Send_Prompt,
	Payload_Update_Diskfile,
	Payload_Delete_Diskfile,
	Payload_Create_Directory,
]);
export type Payload_Client = z.infer<typeof Payload_Client>;

// Union of all server payload types
export const Payload_Server = z.discriminatedUnion('type', [
	Payload_Pong,
	Payload_Loaded_Session,
	Payload_Filer_Change,
	Payload_Completion_Response,
]);
export type Payload_Server = z.infer<typeof Payload_Server>;

// Union of all payload types
export const Payload = z.discriminatedUnion('type', [
	Payload_Ping,
	Payload_Pong,
	Payload_Load_Session,
	Payload_Loaded_Session,
	Payload_Filer_Change,
	Payload_Send_Prompt,
	Payload_Completion_Response,
	Payload_Update_Diskfile,
	Payload_Delete_Diskfile,
	Payload_Create_Directory,
]);
export type Payload = z.infer<typeof Payload>;

// Payload with metadata schema
export const Payload_Json = Cell_Json.extend({
	type: Payload_Type,
	direction: Payload_Direction,
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
export type Payload_Json = z.infer<typeof Payload_Json>;

// Helper function to create a payload with json representation
export const create_payload_json = (
	payload: Payload,
	direction: Payload_Direction,
): Payload_Json => {
	return {
		...payload,
		direction,
		created: Datetime_Now.parse(undefined),
	} as Payload_Json;
};
