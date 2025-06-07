import {Hono} from 'hono';

import type {Zzz_Server} from '$lib/server/zzz_server.js';
import {Path_Without_Trailing_Slash} from '$lib/zod_helpers.js';
import {create_jsonrpc_error_message_from_thrown} from '$lib/jsonrpc_helpers.js';

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

	// TODO BLOCK @api use `GET` when `side_effects` is null

	app.post(final_path, async (c) => {
		try {
			const json = await c.req.json();
			const response = await server.receive(json);
			return c.json(response);
		} catch (error) {
			console.error('[http] error processing JSON-RPC request:', error);
			return c.json(create_jsonrpc_error_message_from_thrown('', error), 400);
		}
	});
};
