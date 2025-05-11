import type {Hono} from 'hono';
import type {WSContext} from 'hono/ws';
import type {createNodeWebSocket} from '@hono/node-ws';

import type {Zzz_Server} from '$lib/server/zzz_server.js';
import {should_allow_origin} from '$lib/server/security.js';
import type {Action_Message_From_Server} from '$lib/action_collections.js';
import {JSONRPCRequest} from '$lib/jsonrpc.js';
import {Api_Error} from '$lib/api.js';

export interface Register_Websocket_Actions_Options {
	app: Hono;
	zzz_server: Zzz_Server;
	upgradeWebSocket: ReturnType<typeof createNodeWebSocket>['upgradeWebSocket'];
	sockets?: Set<WSContext>;
}

/**
 * Registers websocket endpoints and handlers.
 */
export const register_websocket_actions = ({
	app,
	zzz_server,
	upgradeWebSocket,
	sockets = new Set<WSContext>(),
}: Register_Websocket_Actions_Options): Set<WSContext> => {
	app.get(
		'/ws',
		/**
		 * @see https://hono.dev/helpers/websocket
		 */
		(c, next) => {
			console.log(`c.req`, c.req.url);
			const origin = c.req.header('origin');
			console.log(`c.req origin`, origin);

			if (!should_allow_origin(origin)) {
				c.status(403);
			}

			return next();
		},
		upgradeWebSocket(() => {
			return {
				onOpen(event, ws) {
					sockets.add(ws);
					console.log('[ws] ws opened', event);
				},
				async onMessage(event, ws) {
					await handle_websocket_message(event.data, {ws, zzz_server});
				},
				onClose: (event, ws) => {
					sockets.delete(ws);
					console.log('[ws] ws closed', event);
				},
			};
		}),
	);

	return sockets;
};

/**
 * Handles websocket messages for service actions.
 */
export const handle_websocket_message = async (
	message_data: unknown,
	options: {ws: WSContext; zzz_server: Zzz_Server},
): Promise<void> => {
	const {ws, zzz_server} = options;

	let data;
	try {
		data = JSON.parse(String(message_data));
	} catch (error) {
		console.error(`received non-json message`, message_data, error);
		return;
	}

	console.log(`[ws] handling message`, data);

	const jsonrpc_request = JSONRPCRequest.safeParse(data);
	if (!jsonrpc_request.success) {
		throw new Api_Error(400, 'Invalid JSON-RPC request');
	}

	// Process with the jsonrpc_server
	const response = await zzz_server.jsonrpc_server.process_request(data);

	// Only send a response if it's not a notification (which doesn't expect a response)
	if (response) {
		ws.send(JSON.stringify(response));
	}
};

/**
 * Send a message to WebSocket clients
 */
export const send_to_websocket_clients = (
	sockets: Set<WSContext>,
	message: Action_Message_From_Server,
	zzz_server: Zzz_Server,
): void => {
	// Create a JSON-RPC notification
	const notification = zzz_server.jsonrpc_server.create_notification(message.method, message);

	// Send to all connected clients
	for (const socket of sockets) {
		socket.send(JSON.stringify(notification));
	}
};
