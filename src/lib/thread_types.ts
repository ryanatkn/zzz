import {z} from 'zod';

import {ModelName} from '$lib/model.svelte.js';
import {CellJson} from '$lib/cell_types.js';
import {TurnJson} from '$lib/turn_types.js';

// TODO add thread name and make it editable
export const ThreadJson = CellJson.extend({
	model_name: ModelName.default(''),
	turns: z.array(TurnJson).default(() => []),
	enabled: z.boolean().default(true),
}).meta({cell_class_name: 'Thread'});
export type ThreadJson = z.infer<typeof ThreadJson>;
export type ThreadJsonInput = z.input<typeof ThreadJson>;
