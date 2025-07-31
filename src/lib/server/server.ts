import {Hono} from 'hono';
import {serve} from '@hono/node-server';
import {createNodeWebSocket} from '@hono/node-ws';
import {Logger} from '@ryanatkn/belt/log.js';
import {ALLOWED_ORIGINS} from '$env/static/private';

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
	WEBSOCKET_PATH,
	ZZZ_CACHE_DIR,
} from '$lib/constants.js';
import {parse_allowed_origins, verify_origin} from '$lib/server/security.js';
import {handle_filer_change} from '$lib/server/backend_actions_api.js';
import {Ollama_Backend_Provider} from '$lib/server/ollama_backend_provider.js';
import {Claude_Backend_Provider} from '$lib/server/claude_backend_provider.js';
import {Chatgpt_Backend_Provider} from '$lib/server/chatgpt_backend_provider.js';
import {Gemini_Backend_Provider} from '$lib/server/gemini_backend_provider.js';

const log = new Logger('[server]');

const create_server = (): void => {
	// TODO better config
	const config = create_config();

	// Security: allow only the configured server URL, extend with care
	const allowed_origins = parse_allowed_origins(ALLOWED_ORIGINS);

	// TODO better logging
	log.info('creating server', {
		config,
		ZZZ_CACHE_DIR,
		allowed_origins,
	});

	const app = new Hono();

	// Security: first verify the origin of incoming requests
	app.use(verify_origin(allowed_origins));

	const {injectWebSocket, upgradeWebSocket} = createNodeWebSocket({app});

	const backend = new Backend({
		zzz_cache_dir: ZZZ_CACHE_DIR, // is the default
		config,
		action_specs,
		action_handlers: backend_action_handlers,
		handle_filer_change,
	});

	// TODO from config
	backend.add_provider(new Ollama_Backend_Provider(backend));
	backend.add_provider(new Claude_Backend_Provider(backend));
	backend.add_provider(new Chatgpt_Backend_Provider(backend));
	backend.add_provider(new Gemini_Backend_Provider(backend));

	// TODO options for everything, maybe a nullable array and an enable/disable flag

	if (WEBSOCKET_PATH) {
		register_websocket_actions({
			path: WEBSOCKET_PATH,
			app,
			backend,
			upgradeWebSocket,
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
