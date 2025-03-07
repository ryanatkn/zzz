import {z} from 'zod';

import {Model_Name} from '$lib/model.svelte.js';
import {Uuid, Datetime_Now} from '$lib/zod_helpers.js';
import {Cell_Json} from '$lib/cell_types.js';
import {cell_array} from '$lib/cell_helpers.js';

export const Tape_Json = Cell_Json.extend({
	id: Uuid,
	created: Datetime_Now,
	model_name: Model_Name.default(''),
	chat_messages: cell_array(
		z.array(z.any()).default(() => []),
		'Chat_Message',
	),
});
export type Tape_Json = z.infer<typeof Tape_Json>;
