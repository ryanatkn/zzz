import {z} from 'zod';

import {Jsonrpc_Request_Id} from '$lib/jsonrpc.js';
import {Datetime_Now, Uuid_With_Default} from '$lib/zod_helpers.js';
import {Action_Method} from '$lib/action_metatypes.js';

// TODO BLOCK @api rework this
/**
 * Base schema for all actions with common properties.
 *
 * Similar to `Cell` json pattern but omits `updated` because they're typically immutable.
 */
export const Action_Message_Base = z
	.object({
		id: Uuid_With_Default, // TODO this means we're trusting client ids, revisit, also probably don't want a default here so we get parse errors
		created: Datetime_Now, // TODO like with id, probably dont want a default on the base schema like this
		method: Action_Method,
		jsonrpc_message_id: Jsonrpc_Request_Id.nullable(),
	})
	.passthrough(); // TODO is this a good/safe pattern for base schemas? we're doing this so we can parse loosely sometimes, but see too how the Uuid has a fallback
export type Action_Message_Base = z.infer<typeof Action_Message_Base>;
