import type {Hono} from 'hono';
import type {createNodeWebSocket} from '@hono/node-ws';
import {wait} from '@ryanatkn/belt/async.js';

import type {Backend} from '$lib/server/backend.js';
import {BACKEND_ARTIFICIAL_RESPONSE_DELAY} from '$lib/constants.js';
import {Backend_Websocket_Transport} from '$lib/server/backend_websocket_transport.js';
import {jsonrpc_error_messages} from '$lib/jsonrpc_errors.js';
import {
	create_jsonrpc_error_message_from_thrown,
	to_jsonrpc_message_id,
} from '$lib/jsonrpc_helpers.js';

export interface Register_Websocket_Actions_Options {
	path: string;
	app: Hono;
	backend: Backend;
	/**
	 * @see https://hono.dev/helpers/websocket
	 */
	upgradeWebSocket: ReturnType<typeof createNodeWebSocket>['upgradeWebSocket'];
	transport?: Backend_Websocket_Transport;
}

/**
 * Registers websocket endpoints for all service actions in the schema registry.
 */
export const register_websocket_actions = ({
	path,
	app,
	backend,
	upgradeWebSocket,
	transport = new Backend_Websocket_Transport(),
}: Register_Websocket_Actions_Options): void => {
	backend.peer.transports.register_transport(transport);

	app.get(
		path,
		upgradeWebSocket(() => ({
			onOpen: (event, ws) => {
				const connection_id = transport.add_connection(ws);
				backend.log?.debug('[ws] ws opened', connection_id, event);
			},
			onMessage: async (event, ws) => {
				let json;
				try {
					json = JSON.parse(String(event.data)); // eslint-disable-line @typescript-eslint/no-base-to-string
				} catch (error) {
					backend.log?.error(`[ws] JSON parse error:`, error);
					ws.send(JSON.stringify(jsonrpc_error_messages.parse_error()));
					return;
				}

				if (BACKEND_ARTIFICIAL_RESPONSE_DELAY > 0) {
					backend.log?.debug(`[ws] throttling ${BACKEND_ARTIFICIAL_RESPONSE_DELAY}ms`);
					await wait(BACKEND_ARTIFICIAL_RESPONSE_DELAY);
				}

				try {
					const response = await backend.receive(json);
					// No responses for notifications
					if (response != null) {
						ws.send(JSON.stringify(response));
					}
				} catch (error) {
					// TODO maybe only return messages if it's req/res? breaks from http version tho
					backend.log?.error('[ws] error processing JSON-RPC request:', error);
					const error_response = create_jsonrpc_error_message_from_thrown(
						to_jsonrpc_message_id(json),
						error,
					);
					ws.send(JSON.stringify(error_response));
				}
			},
			onClose: (event, ws) => {
				transport.remove_connection(ws);
				backend.log?.debug('[ws] ws closed', event);
			},
		})),
	);
};
