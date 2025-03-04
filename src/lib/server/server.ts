import {Hono} from 'hono';
import {serve} from '@hono/node-server';
import {createNodeWebSocket} from '@hono/node-ws';
import type {WSContext} from 'hono/ws';
import * as devalue from 'devalue';
import {PUBLIC_SERVER_HOSTNAME, PUBLIC_SERVER_PORT} from '$env/static/public';

import {Zzz_Server} from '$lib/server/zzz_server.js';
import create_config from '$lib/config.js';
import type {Message_Server} from '$lib/message_types.js';

console.log('creating server');

const {system_message} = await create_config();

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
				if (data.type === 'gro_server_message') {
					let message: Message_Server | null;
					try {
						message = await zzz_server.receive(data.message);
					} catch (err) {
						console.error('error in `receive` handler', err);
						// TODO send error back with `data.message.id`
						return;
					}
					if (message) {
						ws.send(devalue.stringify({type: 'gro_server_message', message}));
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

const server = serve(
	{
		fetch: app.fetch,
		hostname: PUBLIC_SERVER_HOSTNAME,
		port: parseInt(PUBLIC_SERVER_PORT, 10) || 8999,
	},
	(info) => {
		console.log(`[server] listening on http://${info.address}:${info.port}`);
	},
);

injectWebSocket(server);

const zzz_server = new Zzz_Server({
	send_to_all_clients: (message) => {
		for (const ws of sockets) {
			ws.send(devalue.stringify({type: 'gro_server_message', message}));
		}
	},
	// providers, // TODO ?
	system_message,
});
