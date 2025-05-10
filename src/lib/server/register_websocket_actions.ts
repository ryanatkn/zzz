import type {Hono} from 'hono';
import type {WSContext} from 'hono/ws';
import * as devalue from 'devalue';

import type {Zzz_Server} from '$lib/server/zzz_server.js';
import {Action_Message_From_Client} from '$lib/action_collections.js';
import {service_return_to_api_result} from '$lib/server/service.js';
import {to_failed_api_result, type Api_Result} from '$lib/api.js';
import {should_allow_origin} from '$lib/server/security.js';
import type {createNodeWebSocket} from '@hono/node-ws';

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

			if (!should_allow_origin(origin + 'sd')) {
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

	// Only handle server_message type messages
	if (data.type !== 'server_message') {
		console.error('unknown message type', data.type);
		return;
	}

	const message = Action_Message_From_Client.safeParse(data.message);
	if (!message.success) {
		console.error('invalid message', data.message);
		// Send error back with message id if available
		const error_result: Api_Result = {
			ok: false,
			status: 400,
			message: 'Invalid message format',
		};
		ws.send(devalue.stringify({type: 'server_message', message: error_result}));
		return;
	}

	let api_result: Api_Result;
	try {
		const service_return = await zzz_server.receive(message.data.method, message.data);
		api_result = service_return_to_api_result(service_return);
	} catch (error) {
		console.error('Error processing action:', error);
		api_result = to_failed_api_result(error);
	}

	ws.send(devalue.stringify({type: 'server_message', message: api_result}));
};
