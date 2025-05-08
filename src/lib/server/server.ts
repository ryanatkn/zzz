import {Hono} from 'hono';
import {serve} from '@hono/node-server';
import {createNodeWebSocket} from '@hono/node-ws';
import type {WSContext} from 'hono/ws';
import * as devalue from 'devalue';
import {PUBLIC_SERVER_HOSTNAME, PUBLIC_ZZZ_DIR} from '$env/static/public';

import {Zzz_Server} from '$lib/server/zzz_server.js';
import {handle_message, handle_filer_change} from '$lib/server/handler_defaults.js';
import {register_http_actions} from '$lib/server/register_http_actions.js';
import create_config from '$lib/config.js';
import {Action_Client, type Action_Server} from '$lib/schemas.js';
import {action_schemas} from '$lib/schema_metadata.js';
import {SERVER_PROXIED_PORT} from '$lib/constants.js';
import {should_allow_origin} from '$lib/server/security.js';

// Needed because some configured deployment targets in SvelteKit don't support top-level await yet
const main = async () => {
	console.log('creating server with zzz_dir', PUBLIC_ZZZ_DIR); // TODO better logging

	const config = create_config();

	const sockets: Set<WSContext> = new Set();

	const app = new Hono();

	const {injectWebSocket, upgradeWebSocket} = createNodeWebSocket({app});

	// Websockets
	app.get(
		'/ws',
		/**
		 * @see https://hono.dev/helpers/websocket
		 */
		(c, next) => {
			console.log(`c.req`, c.req);
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
					console.log('[server] ws opened', event);
				},
				async onMessage(event, ws) {
					let data;
					try {
						data = JSON.parse(event.data.toString()); // eslint-disable-line @typescript-eslint/no-base-to-string
					} catch (_err) {
						console.error(`received non-json message`, event.data);
						return;
					}
					// console.log(`[server] handling message`, data);
					if (data.type === 'server_message') {
						const parsed = Action_Client.safeParse(data.message);
						if (!parsed.success) {
							console.error('invalid message', data.message);
							// TODO @many send error back with `data.message.id`
							return;
						}
						let message: Action_Server | null;
						try {
							message = await zzz_server.receive(parsed.data);
						} catch (err) {
							console.error('error in `receive` handler', err);
							// TODO @many send error back with `data.message.id`
							return;
						}
						if (message) {
							ws.send(devalue.stringify({type: 'server_message', message}));
						}
					} else {
						console.error('unknown message type', data.type);
					}
				},
				onClose: (event, ws) => {
					sockets.delete(ws);
					console.log('[server] ws closed', event);
				},
			};
		}),
	);

	// Create the server with handlers and configuration
	const zzz_server = new Zzz_Server({
		zzz_dir: PUBLIC_ZZZ_DIR,
		config,
		send_to_all_clients: (message) => {
			for (const ws of sockets) {
				ws.send(devalue.stringify({type: 'server_message', message}));
			}
		},
		handle_message,
		handle_filer_change,
	});

	// Register all http action routes with the action schemas
	register_http_actions({
		app,
		zzz_server,
		action_schemas, // Pass the action schemas from metadata
	});

	const hono = serve(
		{
			fetch: app.fetch,
			hostname: PUBLIC_SERVER_HOSTNAME,
			port: SERVER_PROXIED_PORT,
		},
		(info) => {
			console.log(`[server] listening on http://${info.address}:${info.port}`);
		},
	);

	injectWebSocket(hono);
};

void main().catch((err) => {
	console.error('uncaught error in main', err);
});
