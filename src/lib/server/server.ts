import {Hono} from 'hono';
import {serve} from '@hono/node-server';
import {createNodeWebSocket} from '@hono/node-ws';
import type {WSContext} from 'hono/ws';
import * as devalue from 'devalue';

import {Zzz_Server} from '$lib/server/zzz_server.js';

console.log('creating server');

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
				console.log('ws opened', event);
			},
			async onMessage(event, ws) {
				console.log(`Message from client: ${event.data} - ${typeof event.data}`);
				let data;
				try {
					data = JSON.parse(event.data.toString());
				} catch (_err) {
					console.error(`received non-json message`, event.data);
					return;
				}
				if (data.type === 'gro_server_message') {
					const message = await zzz_server.receive(data.message);
					if (message) {
						ws.send(devalue.stringify({type: 'gro_server_message', message}));
					}
				} else {
					ws.send(devalue.stringify('hi'));
				}
			},
			onClose: (event, ws) => {
				sockets.delete(ws);
				console.log('ws closed', event);
			},
		};
	}),
);

const server = serve(app, (info) => {
	console.log('listening on http://localhost:' + info.port);
});

injectWebSocket(server);

const zzz_server = new Zzz_Server({
	send: (message) => {
		for (const ws of sockets) {
			ws.send(devalue.stringify({type: 'gro_server_message', message}));
		}
	},
	// model_type: 'cheap', // TODO source from env or config?
});
