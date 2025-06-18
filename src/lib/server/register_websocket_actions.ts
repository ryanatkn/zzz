import type {Hono} from 'hono';
import type {createNodeWebSocket} from '@hono/node-ws';

import type {Backend} from '$lib/server/backend.js';
import {verify_origin, type Allowed_Origins} from '$lib/server/security.js';
import {SERVER_URL} from '$lib/constants.js';
import {noop_middleware} from '$lib/server/server_helpers.js';
import {Backend_Websocket_Transport} from '$lib/server/backend_websocket_transport.js';

export interface Register_Websocket_Actions_Options {
	path: string;
	app: Hono;
	backend: Backend;
	/**
	 * @see https://hono.dev/helpers/websocket
	 */
	upgradeWebSocket: ReturnType<typeof createNodeWebSocket>['upgradeWebSocket'];
	/**
	 * For extra security we verify the origin here as well as upstream.
	 * This allows the upstream config to change for other purposes
	 * without affecting the WebSocket endpoint.
	 * The overhead is negligible since it's a one-time check before the upgrade.
	 */
	allowed_origins?: Allowed_Origins | null;
	transport?: Backend_Websocket_Transport;
}

/**
 * Registers websocket endpoints and handlers.
 */
export const register_websocket_actions = ({
	path,
	app,
	backend,
	upgradeWebSocket,
	allowed_origins = [SERVER_URL],
	transport = new Backend_Websocket_Transport(),
}: Register_Websocket_Actions_Options): void => {
	backend.peer.transports.register_transport(transport);

	app.get(
		path,
		allowed_origins ? verify_origin(allowed_origins) : noop_middleware, // TODO better pattern?
		upgradeWebSocket(() => ({
			onOpen: (event, ws) => {
				const connection_id = transport.add_connection(ws);
				console.log('[ws] ws opened', connection_id, event);
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
					const response = await backend.receive(json);
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
				transport.remove_connection(ws);
				console.log('[ws] ws closed', event);
			},
		})),
	);
};
