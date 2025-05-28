import {Hono} from 'hono';

import type {Zzz_Server} from '$lib/server/zzz_server.js';
import {Path_Without_Trailing_Slash} from '$lib/zod_helpers.js';
import {JSONRPC_PARSE_ERROR, JSONRPC_VERSION} from '$lib/jsonrpc.js';

export interface Register_Actions_Options {
	path: string;
	app: Hono;
	server: Zzz_Server;
}

/**
 * Registers HTTP endpoints for all service actions in the schema registry.
 */
export const register_http_actions = ({path, app, server}: Register_Actions_Options): void => {
	// Register a single JSON-RPC endpoint that handles all methods
	const final_path = Path_Without_Trailing_Slash.parse(path);

	// TODO BLOCK @api handle `GET`

	app.post(final_path, async (c) => {
		console.log(`[http] POST ${c.req.url}`);
		try {
			const request_data = await c.req.json();

			const response = await server.handle_jsonrpc_message(request_data);

			return c.json(response);
		} catch (error) {
			console.error('[http] error processing JSON-RPC request:', error);
			return c.json(
				{
					jsonrpc: JSONRPC_VERSION,
					id: null,
					error: {
						code: JSONRPC_PARSE_ERROR,
						message: error instanceof Error ? error.message : 'parse error',
					},
				},
				400,
			);
		}
	});
};
