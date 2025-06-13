// @slop claude_opus_4
// api_client.ts

import type {Deferred, Async_Status} from '@ryanatkn/belt/async.js';

import type {Socket} from '$lib/socket.svelte.js';
import {
	Http_Rpc_Transport,
	Transports,
	Websocket_Rpc_Transport,
	type Transport_Type,
} from '$lib/transports.js';
import type {
	Jsonrpc_Batch_Request,
	Jsonrpc_Batch_Response,
	Jsonrpc_Message_From_Client_To_Server,
	Jsonrpc_Message_From_Server_To_Client,
	Jsonrpc_Notification,
	Jsonrpc_Request,
	Jsonrpc_Response_Or_Error,
} from '$lib/jsonrpc.js';

// TODO support canceling

export interface Api_Client_Options {
	http_rpc_url?: string | null; // TODO optional thunk?
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
 * Works seamlessly with the action event system by handling the underlying transport.
 */
export class Api_Client {
	readonly transports = new Transports();

	constructor(options: Api_Client_Options) {
		// Set up HTTP transport if URL is provided
		if (options.http_rpc_url) {
			this.transports.register_transport(
				new Http_Rpc_Transport(options.http_rpc_url, options.http_headers),
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
	 * Send a message to the server and get a response.
	 * This method is used by the action event system to send JSON-RPC messages.
	 */
	async send(
		message: Jsonrpc_Request,
		transport_type?: Transport_Type,
	): Promise<Jsonrpc_Response_Or_Error>;
	async send(message: Jsonrpc_Notification, transport_type?: Transport_Type): Promise<null>;
	async send(
		message: Jsonrpc_Batch_Request,
		transport_type?: Transport_Type,
	): Promise<Jsonrpc_Batch_Response>;
	async send(
		message: Jsonrpc_Message_From_Client_To_Server,
		transport_type?: Transport_Type,
	): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		const transport = this.transports.get_or_throw(transport_type);
		console.log(`[api_client.send] sending`, transport.type, message);

		const result = await transport.send(message);
		console.log(`[api_client.send] received`, result);

		return result;
	}
}
