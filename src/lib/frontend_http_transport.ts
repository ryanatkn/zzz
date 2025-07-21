// @slop Claude Opus 4

import {Thrown_Jsonrpc_Error, jsonrpc_error_messages} from '$lib/jsonrpc_errors.js';
import {create_jsonrpc_error_message, to_jsonrpc_message_id} from '$lib/jsonrpc_helpers.js';
import type {Transport} from '$lib/transports.js';
import type {
	Jsonrpc_Message_From_Client_To_Server,
	Jsonrpc_Message_From_Server_To_Client,
	Jsonrpc_Notification,
	Jsonrpc_Request,
	Jsonrpc_Response_Or_Error,
	Jsonrpc_Error_Message,
} from '$lib/jsonrpc.js';

export class Frontend_Http_Transport implements Transport {
	readonly transport_name = 'frontend_http_rpc' as const;

	#url: string;
	#headers: Record<string, string>;

	constructor(url: string, headers?: Record<string, string>) {
		this.#url = url;
		this.#headers = headers ?? {'content-type': 'application/json', accept: 'application/json'};
	}

	async send(message: Jsonrpc_Request): Promise<Jsonrpc_Response_Or_Error>;
	async send(message: Jsonrpc_Notification): Promise<Jsonrpc_Error_Message | null>;
	async send(
		message: Jsonrpc_Message_From_Client_To_Server,
	): Promise<Jsonrpc_Message_From_Server_To_Client | null> {
		console.log(`[frontend http transport] message`, message);
		try {
			const response = await fetch(this.#url, {
				method: 'POST', // TODO support GET when `!spec.side_effects`
				headers: this.#headers,
				body: JSON.stringify(message),
				// TODO
				// signal: AbortSignal.timeout(REQUEST_TIMEOUT),
			});

			const result = await response.json();
			console.log(`send result`, result);

			// For JSON-RPC, we always expect a 200 OK response
			// The actual error will be in the JSON-RPC error field
			if (!response.ok) {
				console.error(
					'[frontend http transport] HTTP error:',
					response.status,
					response.statusText,
				);
				return create_jsonrpc_error_message(
					to_jsonrpc_message_id(message),
					jsonrpc_error_messages.internal_error(
						`HTTP error: ${response.status} ${response.statusText}`,
					),
				);
			}

			console.log(`[frontend http transport] result`, result);
			return result;
		} catch (error) {
			// TODO @many clean up transport error handling
			console.error('[frontend http transport] error sending HTTP request:', error);

			if (error instanceof Thrown_Jsonrpc_Error) {
				return create_jsonrpc_error_message(to_jsonrpc_message_id(message), {
					code: error.code,
					message: error.message,
					data: error.data,
				});
			}
			return create_jsonrpc_error_message(
				to_jsonrpc_message_id(message),
				jsonrpc_error_messages.internal_error('error sending HTTP request', {
					error: error instanceof Error ? error.message : String(error),
				}),
			);
		}
	}

	is_ready(): boolean {
		// HTTP is always ready
		return true;
	}
}
