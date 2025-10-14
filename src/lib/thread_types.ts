import {z} from 'zod';

import {Model_Name} from '$lib/model.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Turn_Json} from '$lib/turn_types.js';

// TODO add thread name and make it editable
export const Thread_Json = Cell_Json.extend({
	model_name: Model_Name.default(''),
	turns: z.array(Turn_Json).default(() => []),
	enabled: z.boolean().default(true),
}).meta({cell_class_name: 'Thread'});
export type Thread_Json = z.infer<typeof Thread_Json>;
export type Thread_Json_Input = z.input<typeof Thread_Json>;
