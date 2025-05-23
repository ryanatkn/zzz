import {z} from 'zod';

import {Cell} from '$lib/cell.svelte.js';
import {Uuid, Uuid_With_Default} from '$lib/zod_helpers.js';
import {Action_Messages} from '$lib/action_messages.js';
import {Cell_Json} from '$lib/cell_types.js';

export const Strip_Role = z.enum(['user', 'assistant', 'system']);
export type Strip_Role = z.infer<typeof Strip_Role>;

export const Strip_Json = Cell_Json.extend({
	bit_id: Uuid_With_Default,
	tape_id: Uuid.nullable().optional(),
	role: Strip_Role,
	request: Action_Messages.submit_completion_request.optional(),
	response: Action_Messages.submit_completion_response.optional(),
});
export type Strip_Json = z.infer<typeof Strip_Json>;
export type Strip_Json_Input = z.input<typeof Strip_Json>;

export const Strip_Schema = z.instanceof(Cell);
