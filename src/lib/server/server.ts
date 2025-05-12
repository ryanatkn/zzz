import {Hono} from 'hono';
import {serve} from '@hono/node-server';
import {createNodeWebSocket} from '@hono/node-ws';
import * as devalue from 'devalue';
import {PUBLIC_SERVER_HOSTNAME, PUBLIC_ZZZ_DIR} from '$env/static/public';

import {Zzz_Server} from '$lib/server/zzz_server.js';
import {handle_message, handle_filer_change} from '$lib/server/handler_defaults.js';
import {register_http_actions} from '$lib/server/register_http_actions.js';
import {register_websocket_actions} from '$lib/server/register_websocket_actions.js';
import create_config from '$lib/config.js';
import {action_specs} from '$lib/action_collections.js';
import {API_PATH, SERVER_PROXIED_PORT} from '$lib/constants.js';

// TODO proper logging everywhere on the server

// TODO BLOCK maybe `create_server` that takes options to override each of these handlers like `register_http_actions`?
const main = (): void => {
	console.log('creating server with zzz_dir', PUBLIC_ZZZ_DIR); // TODO better logging

	const config = create_config();
	const app = new Hono();
	const {injectWebSocket, upgradeWebSocket} = createNodeWebSocket({app});

	// Create the server with handlers and configuration
	const zzz_server = new Zzz_Server({
		zzz_dir: PUBLIC_ZZZ_DIR,
		config,
		action_specs,
		send_to_all_clients: (message) => {
			// Send messages to all connected websocket clients
			for (const ws of sockets) {
				ws.send(devalue.stringify(message));
			}
		},
		handle_message,
		handle_filer_change,
	});

	// TODO options for everything, maybe a nullable array and an enable/disable flag
	// Register websocket handlers and store the sockets collection
	const sockets = register_websocket_actions({
		app,
		zzz_server,
		upgradeWebSocket,
	});

	// Register all http action routes with the action schemas
	register_http_actions({
		app,
		zzz_server,
		path: API_PATH,
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

// Some configured deployment targets in SvelteKit don't support top-level await yet but this is sync atm
try {
	main(); // TODO BLOCK change this to be `main.ts` and `create_server.ts`
} catch (error) {
	console.error('error starting server:', error);
	throw error;
}
