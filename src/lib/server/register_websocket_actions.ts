import type {Hono} from 'hono';
import type {WSContext} from 'hono/ws';
import type {createNodeWebSocket} from '@hono/node-ws';

import type {Zzz_Server} from '$lib/server/zzz_server.js';
import {verify_origin, type Allowed_Origins} from '$lib/server/security.js';
import {SERVER_URL} from '$lib/constants.js';

export interface Register_Websocket_Actions_Options {
	path: string;
	app: Hono;
	server: Zzz_Server;
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
	server,
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
		upgradeWebSocket(() => ({
			onOpen: (event, ws) => {
				sockets.add(ws);
				console.log('[ws] ws opened', event);
			},
			onMessage: async (event, ws) => {
				let data;
				try {
					data = JSON.parse(String(event.data)); // eslint-disable-line @typescript-eslint/no-base-to-string
				} catch (error) {
					console.error(`[ws] received non-json message`, event.data, error);
					return;
				}

				console.log(`[ws] handling message`, data);

				const response = await server.handle_jsonrpc_message(data);

				// Only send a response if it's not a notification (which doesn't expect a response)
				if (response != null) {
					ws.send(JSON.stringify(response));
				}
			},
			onClose: (event, ws) => {
				sockets.delete(ws);
				console.log('[ws] ws closed', event);
			},
		})),
	);

	return sockets;
};
