import {z} from 'zod';

import {Any, Datetime_Now, Uuid, Uuid_With_Default} from '$lib/zod_helpers.js';
import {Completion_Response, Completion_Request} from '$lib/completion_types.js';
import {Action_Message_Type, Action_Method} from '$lib/action_metatypes.js';
import {Diskfile_Change, Diskfile_Path, Serializable_Source_File} from '$lib/diskfile_types.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Jsonrpc_Request_Id} from '$lib/jsonrpc.js';

/**
 * Flag to indicate the phase of a request/response action.
 * - 'request': The action is being sent to the server
 * - 'response': The server has responded to the action
 * - null: The action is not a request/response type (e.g., client_local, server_notification)
 */
// TODO BLOCK @api rethink this
export const Action_Request_Response_Flag = z.union([
	z.literal('request'),
	z.literal('response'),
	z.null(),
]);
export type Action_Request_Response_Flag = z.infer<typeof Action_Request_Response_Flag>;

// TODO BLOCK Action_Message and Action_Message_Json? but not cells?
/**
 * Base schema for all actions with common properties.
 *
 * Similar to `Cell` but omits `updated` because they're typically immutable.
 */
export const Action_Message_Base = z
	.object({
		id: Uuid_With_Default, // TODO this means we're trusting client ids, revisit, also probably don't want a default here so we get parse errors
		created: Datetime_Now, // TODO like with id, probably dont want a default on the base schema like this
		type: Action_Message_Type,
		method: Action_Method,
		jsonrpc_message_id: Jsonrpc_Request_Id.nullable(),
	})
	.passthrough(); // TODO is this a good/safe pattern for base schemas? we're doing this so we can parse loosely sometimes, but see too how the Uuid has a fallback
export type Action_Message_Base = z.infer<typeof Action_Message_Base>;

export const Action_Kind = z.enum(['request_response', 'server_notification', 'client_local']);
export type Action_Kind = z.infer<typeof Action_Kind>;

export const Action_Json = Cell_Json.extend({
	type: Action_Message_Type,
	method: Action_Method,
	params: Any.optional(),
	kind: Action_Kind, // TODO BLOCK doesn't belong here, can be looked up from the method or type
	jsonrpc_message_id: Jsonrpc_Request_Id.nullable(),
	// TODO BLOCK this is hacky, maybe just a generic `params: Any`?
	ping_id: Uuid.optional(),
	completion_request: Completion_Request.optional(),
	completion_response: Completion_Response.optional(),
	path: Diskfile_Path.optional(),
	content: z.string().optional(),
	change: Diskfile_Change.optional(),
	source_file: Serializable_Source_File.optional(),
	data: z.record(z.string(), z.any()).optional(),
}).strict();
export type Action_Json = z.infer<typeof Action_Json>;
export type Action_Json_Input = z.input<typeof Action_Json>;
