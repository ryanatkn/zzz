import type {Hono} from 'hono';
import type {WSContext} from 'hono/ws';
import type {createNodeWebSocket} from '@hono/node-ws';

import type {Zzz_Server} from '$lib/server/zzz_server.js';
import {verify_origin, type Allowed_Origins} from '$lib/server/security.js';
import {SERVER_URL} from '$lib/constants.js';
import {noop_middleware} from '$lib/server/server_helpers.js';

export interface Register_Websocket_Actions_Options {
	path: string;
	app: Hono;
	server: Zzz_Server;
	/**
	 * @see https://hono.dev/helpers/websocket
	 */
	upgradeWebSocket: ReturnType<typeof createNodeWebSocket>['upgradeWebSocket'];
	sockets?: Set<WSContext>;
	/**
	 * For extra security we verify the origin here as well as upstream.
	 * This allows the upstream config to change for other purposes
	 * without affecting the WebSocket endpoint.
	 * The overhead is negligible since it's a one-time check before the upgrade.
	 */
	allowed_origins?: Allowed_Origins | null;
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
		allowed_origins ? verify_origin(allowed_origins) : noop_middleware, // TODO better pattern?
		upgradeWebSocket(() => ({
			onOpen: (event, ws) => {
				sockets.add(ws);
				console.log('[ws] ws opened', event);
			},
			onMessage: async (event, ws) => {
				let json;
				try {
					json = JSON.parse(String(event.data)); // eslint-disable-line @typescript-eslint/no-base-to-string
				} catch (error) {
					console.error(`[ws] received non-json message`, error);
					return;
				}

				try {
					const response = await server.handle_jsonrpc_message(json);
					// No responses for notifications
					if (response != null) {
						ws.send(JSON.stringify(response));
					}
				} catch (error) {
					console.error(`[ws] error handling jsonrpc message`, error);
					return;
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
