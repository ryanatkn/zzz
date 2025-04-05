import {Hono} from 'hono';
import {serve} from '@hono/node-server';
import {createNodeWebSocket} from '@hono/node-ws';
import type {WSContext} from 'hono/ws';
import * as devalue from 'devalue';
import {PUBLIC_SERVER_HOSTNAME, PUBLIC_ZZZ_DIR} from '$env/static/public';

import {Zzz_Server} from '$lib/server/zzz_server.js';
import {handle_message, handle_filer_change} from '$lib/server/handler_defaults.js';
import create_config from '$lib/config.js';
import type {Payload_Server} from '$lib/payload_types.js';
import {package_json} from '$routes/package.js';
import {SERVER_PROXIED_PORT} from '$lib/constants.js';

// Needed because some configured deployment targets in SvelteKit don't support top-level await yet
const main = async () => {
	console.log('creating server with zzz_dir', PUBLIC_ZZZ_DIR); // TODO better logging

	const config = create_config();

	const sockets: Set<WSContext> = new Set();

	const app = new Hono();

	const {injectWebSocket, upgradeWebSocket} = createNodeWebSocket({app});

	app.get('/', (c) => {
		const r = c.text('hello world');
		console.log(`r`, r);
		return r;
	});

	app.get(
		'/ws',
		/**
		 * @see https://hono.dev/helpers/websocket
		 */
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
						let message: Payload_Server | null;
						try {
							message = await zzz_server.receive(data.message);
						} catch (err) {
							console.error('error in `receive` handler', err);
							// TODO send error back with `data.message.id`
							return;
						}
						if (message) {
							ws.send(devalue.stringify({type: 'server_message', message}));
						}
					} else {
						ws.send(devalue.stringify('hi'));
					}
				},
				onClose: (event, ws) => {
					sockets.delete(ws);
					console.log('[server] ws closed', event);
				},
			};
		}),
	);

	app.get('/api/ping', (c) => {
		return c.json({
			name: package_json.name,
			version: package_json.version,
		});
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
};

void main().catch((err) => {
	console.error('uncaught error in main', err);
});
