import {Hono} from 'hono';
import {serve} from '@hono/node-server';
import {createNodeWebSocket} from '@hono/node-ws';
import {Logger} from '@ryanatkn/belt/log.js';

import {Backend} from '$lib/server/backend.js';
import {backend_action_handlers} from '$lib/server/backend_action_handlers.js';
import {register_http_actions} from '$lib/server/register_http_actions.js';
import {register_websocket_actions} from '$lib/server/register_websocket_actions.js';
import create_config from '$lib/config.js';
import {action_specs} from '$lib/action_collections.js';
import {
	API_PATH_FOR_HTTP_RPC,
	SERVER_HOST,
	SERVER_PROXIED_PORT,
	SERVER_URL,
	WEBSOCKET_PATH,
	ZZZ_DIR,
} from '$lib/constants.js';
import {verify_origin} from '$lib/server/security.js';
import {handle_filer_change} from '$lib/server/backend_actions_api.js';

const log = new Logger('[server]');

const create_server = (): void => {
	// TODO better config
	const config = create_config();
	// Security: allow only the configured server URL, extend with care
	const allowed_origins = [SERVER_URL];

	// TODO better logging
	log.info('creating server', {config, ZZZ_DIR, allowed_origins});

	const app = new Hono();

	// Security: first verify the origin of incoming requests
	app.use(verify_origin(allowed_origins));

	const {injectWebSocket, upgradeWebSocket} = createNodeWebSocket({app});

	const backend = new Backend({
		zzz_dir: ZZZ_DIR,
		config,
		action_specs,
		action_handlers: backend_action_handlers,
		handle_filer_change,
	});

	// TODO options for everything, maybe a nullable array and an enable/disable flag

	if (WEBSOCKET_PATH) {
		register_websocket_actions({
			path: WEBSOCKET_PATH,
			app,
			backend,
			upgradeWebSocket,
			allowed_origins, // TODO is this good or should they be separate?
		});
	}

	if (API_PATH_FOR_HTTP_RPC) {
		register_http_actions({
			path: API_PATH_FOR_HTTP_RPC,
			app,
			backend,
			// TODO allowed_origins ?
		});
	}

	const hono = serve(
		{
			hostname: SERVER_HOST,
			port: SERVER_PROXIED_PORT,
			fetch: app.fetch,
		},
		(info) => {
			log.info(`listening on http://${info.address}:${info.port}`);
		},
	);

	injectWebSocket(hono);
};

// Some configured deployment targets in SvelteKit don't support top-level await yet but this is sync atm
try {
	create_server();
} catch (error) {
	log.error('error starting server:', error);
	throw error;
}
