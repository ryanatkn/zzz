import {z} from 'zod';

import type {Action_Spec} from '$lib/action_spec.js';
import {Jsonrpc_Request_Id, type Jsonrpc_Singular_Message} from '$lib/jsonrpc.js';
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

// TODO BLOCK @api this is not used, but maybe something like it should be?
/**
 * Immutable wrapper around JSON-RPC messages.
 */
export class Action_Message {
	readonly jsonrpc_message: Jsonrpc_Singular_Message;
	readonly spec: Action_Spec;

	constructor(jsonrpc_message: Jsonrpc_Singular_Message, spec: Action_Spec) {
		this.jsonrpc_message = jsonrpc_message;
		this.spec = spec;
	}

	// TODO BLOCK maybe have a type union for these for better type safety? use this logic in a static method, like `from_jsonrpc_message`
	get is_request(): boolean {
		return 'id' in this.jsonrpc_message && 'method' in this.jsonrpc_message;
	}

	get is_response(): boolean {
		return 'id' in this.jsonrpc_message && 'result' in this.jsonrpc_message;
	}

	get is_notification(): boolean {
		return 'method' in this.jsonrpc_message && !('id' in this.jsonrpc_message);
	}

	get is_error(): boolean {
		return 'id' in this.jsonrpc_message && 'error' in this.jsonrpc_message;
	}

	get method(): string {
		return this.spec.method;
	}

	get id(): string | number | null {
		return 'id' in this.jsonrpc_message ? this.jsonrpc_message.id : null;
	}
}
