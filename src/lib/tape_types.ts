import {z} from 'zod';

import {Model_Name} from '$lib/model.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {cell_array} from '$lib/cell_helpers.js';
import {Strip_Json} from '$lib/strip.svelte.js';

// TODO BLOCK add tape name and make it editable
export const Tape_Json = Cell_Json.extend({
	model_name: Model_Name.default(''),
	strips: cell_array(
		z.array(Strip_Json).default(() => []),
		'Strip',
	),
	enabled: z.boolean().default(true),
});
export type Tape_Json = z.infer<typeof Tape_Json>;
export type Tape_Json_Input = z.input<typeof Tape_Json>;

export const Tape_Role = z.enum(['user', 'system', 'assistant']);
export type Tape_Role = z.infer<typeof Tape_Role>;

export const Tape_Message = z.object({
	role: Tape_Role,
	content: z.string(),
});
export type Tape_Message = z.infer<typeof Tape_Message>;
