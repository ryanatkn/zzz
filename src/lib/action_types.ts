import {z} from 'zod';

import {Uuid} from '$lib/zod_helpers.js';
import {Completion_Response, Completion_Request} from '$lib/tape_types.js';
import {Action_Method} from '$lib/action_metatypes.js';
import {Diskfile_Change, Diskfile_Path, Source_File} from '$lib/diskfile_types.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Action_Direction} from '$lib/action_spec.js';

export const Action_Json = Cell_Json.extend({
	method: Action_Method,
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
