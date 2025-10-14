import {z} from 'zod';

import {Cell} from '$lib/cell.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Completion_Request, Completion_Response, Completion_Role} from '$lib/completion_types.js';

/**
 * Turn is a conversation turn (like A2A Message) that references one or more parts (content entities).
 * Turns contextualize reusable content within conversations, providing role, metadata, and ordering.
 */
export const Turn_Json = Cell_Json.extend({
	part_ids: z.array(Uuid).default(() => []),
	thread_id: Uuid.nullable().optional(),
	role: Completion_Role,
	request: Completion_Request.optional(),
	response: Completion_Response.optional(),
	error_message: z.string().optional(),
}).meta({cell_class_name: 'Turn'});
export type Turn_Json = z.infer<typeof Turn_Json>;
export type Turn_Json_Input = z.input<typeof Turn_Json>;

export const Turn_Schema = z.instanceof(Cell);
