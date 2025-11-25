import {Hono} from 'hono';
import {serve, type HttpBindings} from '@hono/node-server';
import {createNodeWebSocket} from '@hono/node-ws';
import {Logger} from '@ryanatkn/belt/log.js';
import {ALLOWED_ORIGINS} from '$env/static/private';
import {DEV} from 'esm-env';

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
import {parse_allowed_origins, verify_request_source} from '$lib/server/security.js';
import {handle_filer_change} from '$lib/server/backend_actions_api.js';
import {BackendProviderOllama} from '$lib/server/backend_provider_ollama.js';
import {BackendProviderClaude} from '$lib/server/backend_provider_claude.js';
import {BackendProviderChatgpt} from '$lib/server/backend_provider_chatgpt.js';
import {BackendProviderGemini} from '$lib/server/backend_provider_gemini.js';
import type {BackendProviderOptions} from './backend_provider.js';

const log = new Logger('[server]');

const create_server = async (): Promise<void> => {
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

	app.use(async (c, next) => {
		// TODO improve this logging
		log.info(
			`[request_begin] ${c.req.method} ${c.req.url} origin(${c.req.header('origin')}) referer(${c.req.header('referer')})`,
		);
		await next();
		log.info(`[request_end] ${c.req.method} ${c.req.url}`);
	});

	// Security: first verify the origin of incoming requests
	app.use(verify_request_source(allowed_origins));

	const {injectWebSocket, upgradeWebSocket} = createNodeWebSocket({app});

	const backend = new Backend({
		zzz_cache_dir: ZZZ_CACHE_DIR, // is the default
		config,
		action_specs,
		action_handlers: backend_action_handlers,
		handle_filer_change,
	});

	// TODO manage these dynamically, init from config/state
	const provider_options: BackendProviderOptions = {
		on_completion_progress: backend.api.completion_progress,
	};
	backend.add_provider(new BackendProviderOllama(provider_options));
	backend.add_provider(new BackendProviderClaude(provider_options));
	backend.add_provider(new BackendProviderChatgpt(provider_options));
	backend.add_provider(new BackendProviderGemini(provider_options));

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

	// In production with the Node adapter, mount the SvelteKit handler to serve the frontend.
	if (!DEV) {
		try {
			// Dynamically import the handler from the SvelteKit build output.

			// TODO we don't want the path statically analyzed and bundled so the path is constructed --
			// instead this should probably be configured as an external in the Gro server plugin
			const handler_path = '../../' + 'build/handler.js'; // eslint-disable-line no-useless-concat

			const {handler} = await import(handler_path);

			// Let SvelteKit handle everything else, including serving prerendered pages and static assets.
			// Pass Node.js native request/response objects to the SvelteKit handler.

			// TODO this casting is hacky, declaring the `hono` instance above like this causes
			// the HttpBindings type to propagate to other interfaces, which I don't want right now
			(app as unknown as Hono<{Bindings: HttpBindings}>).use('*', async (c) => {
				await handler(c.env.incoming, c.env.outgoing);
				// The handler writes directly to c.env.outgoing, so return a Response with
				// the x-hono-already-sent header to tell Hono not to process the response.
				return new Response(null, {headers: {'x-hono-already-sent': 'true'}});
			});
		} catch (error) {
			log.error(
				'failed to load SvelteKit handler -- was the Node adapter correctly used with `ZZZ_BUILD=node gro build`?',
				error,
			);
			throw error;
		}
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

void create_server().catch((error) => {
	log.error('error starting server:', error);
	throw error;
});
