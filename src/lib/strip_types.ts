import {z} from 'zod';

import {Cell} from '$lib/cell.svelte.js';
import {Uuid, Uuid_With_Default} from '$lib/zod_helpers.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Completion_Request, Completion_Response, Completion_Role} from '$lib/completion_types.js';

export const Strip_Json = Cell_Json.extend({
	bit_id: Uuid_With_Default,
	tape_id: Uuid.nullable().optional(),
	role: Completion_Role,
	request: Completion_Request.optional(),
	response: Completion_Response.optional(),
});
export type Strip_Json = z.infer<typeof Strip_Json>;
export type Strip_Json_Input = z.input<typeof Strip_Json>;

export const Strip_Schema = z.instanceof(Cell);
