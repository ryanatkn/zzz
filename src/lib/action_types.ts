import {z} from 'zod';

import {Any, Uuid} from '$lib/zod_helpers.js';
import {Completion_Response, Completion_Request} from '$lib/completion_types.js';
import {Action_Message_Type, Action_Method} from '$lib/action_metatypes.js';
import {Diskfile_Change, Diskfile_Path, Serializable_Source_File} from '$lib/diskfile_types.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Action_Kind} from '$lib/action_spec.js';

export const Action_Json = Cell_Json.extend({
	type: Action_Message_Type,
	method: Action_Method,
	params: Any.optional(),
	kind: Action_Kind,
	// Optional fields with proper type checking
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
