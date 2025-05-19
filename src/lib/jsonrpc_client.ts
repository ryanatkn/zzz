import type {
	JSONRPCMethod,
	JSONRPCNotification,
	JSONRPCNotificationParams,
	JSONRPCRequest,
	JSONRPCRequestId,
	JSONRPCRequestParams,
} from '$lib/jsonrpc.js';
import {create_uuid} from '$lib/zod_helpers.js';
import type {Transport_Type, Transports} from '$lib/transport.js';

export interface Jsonrpc_Client_Options {
	transports: Transports;
}

// TODO BLOCK maybe make these plain functions since the class is stateless and rename to `jsonrpc_helpers.ts`

/**
 * JSON-RPC client that supports multiple transports with flexible usage.
 */
export class Jsonrpc_Client {
	transports: Transports;

	constructor(options: Jsonrpc_Client_Options) {
		this.transports = options.transports;
	}

	/**
	 * Sends a JSON-RPC request.
	 */
	send(
		method: JSONRPCMethod,
		params: JSONRPCRequestParams | void,
		id: JSONRPCRequestId = create_uuid(),
		transport_type?: Transport_Type,
	): void {
		console.log(`send`, method, params, id);
		const transport = this.transports.get_or_throw(transport_type);

		const message: JSONRPCRequest = {
			jsonrpc: '2.0',
			id,
			method,
		};
		if (params !== undefined) {
			message.params = params;
		}

		transport.send(message);
	}

	/**
	 * Sends a JSON-RPC notification (no response expected).
	 */
	notify(
		method: JSONRPCMethod,
		params: JSONRPCNotificationParams | void,
		transport_type?: Transport_Type,
	): void {
		console.log(`notify`, method, params);
		const transport = this.transports.get_or_throw(transport_type);

		const message: JSONRPCNotification = {
			jsonrpc: '2.0',
			method,
		};
		if (params !== undefined) {
			message.params = params;
		}

		transport.send(message);
	}
}
