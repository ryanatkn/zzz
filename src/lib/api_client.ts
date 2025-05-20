import type {Deferred, Async_Status} from '@ryanatkn/belt/async.js';

import type {Socket} from '$lib/socket.svelte.js';
import {
	Http_Rpc_Transport,
	Transports,
	Websocket_Rpc_Transport,
	type Transport_Type,
} from '$lib/transports.js';
import type {JSONRPCRequest} from '$lib/jsonrpc.js';

// TODO support canceling

export interface Api_Client_Options {
	http_url?: string | null; // TODO optional thunk?
	http_headers?: Record<string, string>; // TODO optional thunk?
	socket?: Socket | null;
	default_transport_type?: Transport_Type; // TODO optional thunk?
}

export interface Request_Tracker<T> {
	deferred: Deferred<T>;
	method: string;
	created: string;
	status: Async_Status;
	timeout?: NodeJS.Timeout;
}

/**
 * Client for communicating with the Zzz server.
 * Uses JSON-RPC for both HTTP and WebSocket communication.
 */
export class Api_Client {
	readonly transports = new Transports();

	constructor(options: Api_Client_Options) {
		// Set up HTTP transport if URL is provided
		if (options.http_url) {
			this.transports.register_transport(
				new Http_Rpc_Transport(options.http_url, options.http_headers),
			);
		}

		// Set up WebSocket transport if socket is provided
		if (options.socket) {
			this.transports.register_transport(new Websocket_Rpc_Transport(options.socket));
			this.transports.set_current_transport('websocket_rpc'); // prefer if available
		}

		if (options.default_transport_type) {
			this.transports.set_current_transport(options.default_transport_type);
		}
	}

	/**
	 * Send an action to the server and get a response.
	 */
	async send<T = any>(request: JSONRPCRequest, transport_type?: Transport_Type): Promise<T> {
		// Send the request
		const transport = this.transports.get_or_throw(transport_type);
		const result = await transport.send(request);
		console.log(`API CLIENT result`, result);
		if (result.ok) {
			return result.value;
		} else {
			// TODO handle error
			console.error('api error', result);
			throw new Error(`API error: ${result.message}`);
		}
	}
}
