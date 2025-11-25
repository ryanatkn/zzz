import {z} from 'zod';

import {Cell} from '$lib/cell.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import {CellJson} from '$lib/cell_types.js';
import {CompletionRequest, CompletionResponse, CompletionRole} from '$lib/completion_types.js';

/**
 * Turn is a conversation turn (like A2A Message) that references one or more parts (content entities).
 * Turns contextualize reusable content within conversations, providing role, metadata, and ordering.
 */
export const TurnJson = CellJson.extend({
	part_ids: z.array(Uuid).default(() => []),
	thread_id: Uuid.nullable().optional(),
	role: CompletionRole,
	request: CompletionRequest.optional(),
	response: CompletionResponse.optional(),
	error_message: z.string().optional(),
}).meta({cell_class_name: 'Turn'});
export type TurnJson = z.infer<typeof TurnJson>;
export type TurnJsonInput = z.input<typeof TurnJson>;

export const TurnSchema = z.instanceof(Cell);
