import {Hono} from 'hono';
import {serve} from '@hono/node-server';
import {createNodeWebSocket} from '@hono/node-ws';
import {PUBLIC_SERVER_HOSTNAME} from '$env/static/public';
import {Logger} from '@ryanatkn/belt/log.js';
import type {WSContext} from 'hono/ws';

import {Zzz_Server} from '$lib/server/zzz_server.js';
import {handle_message, handle_filer_change} from '$lib/server/handler_defaults.js';
import {register_http_actions} from '$lib/server/register_http_actions.js';
import {register_websocket_actions} from '$lib/server/register_websocket_actions.js';
import create_config from '$lib/config.js';
import {action_specs} from '$lib/action_collections.js';
import {
	API_PATH_FOR_HTTP_RPC,
	SERVER_PROXIED_PORT,
	SERVER_URL,
	WEBSOCKET_PATH,
	ZZZ_DIR,
} from '$lib/constants.js';
import {verify_origin} from '$lib/server/security.js';

const log = new Logger('[server]');

// TODO BLOCK maybe `create_server` that takes options to override each of these handlers like `register_http_actions`?
const main = (): void => {
	// TODO better config
	const config = create_config();
	const allowed_origins = [SERVER_URL];

	// TODO better logging
	log.info('creating server', {config, ZZZ_DIR, allowed_origins});

	const app = new Hono();
	const {injectWebSocket, upgradeWebSocket} = createNodeWebSocket({app});

	// Create the server with handlers and configuration
	const zzz_server = new Zzz_Server({
		zzz_dir: ZZZ_DIR,
		config,
		action_specs,
		send_to_all_clients: (message) => {
			if (!sockets) return; // TODO warn?

			// Send messages to all connected websocket clients
			for (const ws of sockets) {
				ws.send(JSON.stringify(message));
			}
		},
		handle_message,
		handle_filer_change,
	});

	app.use(verify_origin(allowed_origins));

	// TODO options for everything, maybe a nullable array and an enable/disable flag
	// Register websocket handlers and store the sockets collection
	let sockets: Set<WSContext> | undefined;
	if (WEBSOCKET_PATH) {
		sockets = register_websocket_actions({
			path: WEBSOCKET_PATH,
			app,
			zzz_server,
			upgradeWebSocket,
			allowed_origins, // TODO is this good or should they be separate?
		});
	}

	// Register all http action routes with the action schemas
	register_http_actions({
		path: API_PATH_FOR_HTTP_RPC,
		app,
		zzz_server,
		// TODO allowed_origins ?
	});

	const hono = serve(
		{
			fetch: app.fetch,
			hostname: PUBLIC_SERVER_HOSTNAME,
			port: SERVER_PROXIED_PORT,
		},
		(info) => {
			log.info(`listening on http://${info.address}:${info.port}`);
		},
	);

	injectWebSocket(hono);
};

// Some configured deployment targets in SvelteKit don't support top-level await yet but this is sync atm
try {
	main(); // TODO BLOCK change this to be `main.ts` and `create_server.ts`
} catch (error) {
	log.error('error starting server:', error);
	throw error;
}
