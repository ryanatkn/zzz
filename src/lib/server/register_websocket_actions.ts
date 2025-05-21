import type {Hono} from 'hono';
import type {WSContext} from 'hono/ws';
import type {createNodeWebSocket} from '@hono/node-ws';

import type {Zzz_Server} from '$lib/server/zzz_server.js';
import {verify_origin, type Allowed_Origins} from '$lib/server/security.js';
import {SERVER_URL} from '$lib/constants.js';

export interface Register_Websocket_Actions_Options {
	path: string;
	app: Hono;
	zzz_server: Zzz_Server;
	upgradeWebSocket: ReturnType<typeof createNodeWebSocket>['upgradeWebSocket'];
	sockets?: Set<WSContext>;
	allowed_origins?: Allowed_Origins;
}

/**
 * Registers websocket endpoints and handlers.
 */
export const register_websocket_actions = ({
	path,
	app,
	zzz_server,
	upgradeWebSocket,
	sockets = new Set<WSContext>(),
	allowed_origins = [SERVER_URL],
}: Register_Websocket_Actions_Options): Set<WSContext> => {
	app.get(
		path,
		verify_origin(allowed_origins),
		/**
		 * @see https://hono.dev/helpers/websocket
		 */
		upgradeWebSocket(() => {
			return {
				onOpen: (event, ws) => {
					sockets.add(ws);
					console.log('[ws] ws opened', event);
				},
				onMessage: async (event, ws) => {
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

	const response = await zzz_server.handle_jsonrpc_message(data);

	// Only send a response if it's not a notification (which doesn't expect a response)
	if (response) {
		ws.send(JSON.stringify(response));
	}
};
