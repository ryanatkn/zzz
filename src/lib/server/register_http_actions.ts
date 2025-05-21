import {Hono} from 'hono';

import type {Zzz_Server} from '$lib/server/zzz_server.js';
import {Path_Without_Trailing_Slash} from '$lib/zod_helpers.js';
import {JSONRPC_VERSION} from '$lib/jsonrpc.js';

export interface Register_Actions_Options {
	path: string;
	app: Hono;
	zzz_server: Zzz_Server;
}

/**
 * Registers HTTP endpoints for all service actions in the schema registry.
 */
export const register_http_actions = ({path, app, zzz_server}: Register_Actions_Options): void => {
	// Register a single JSON-RPC endpoint that handles all methods
	const final_path = Path_Without_Trailing_Slash.parse(path);

	app.post(final_path, async (c) => {
		console.log(`[http] <${c.req.url}>`);
		try {
			const request_data = await c.req.json();

			const response = await zzz_server.handle_jsonrpc_message(request_data);

			// If it's a notification, there's no response
			if (!response) {
				return c.json(null);
			}

			return c.json(response);
		} catch (error) {
			console.error('Error processing JSON-RPC request:', error);
			return c.json(
				{
					jsonrpc: JSONRPC_VERSION,
					id: null,
					error: {
						code: -32700,
						message: error instanceof Error ? error.message : 'Parse error',
					},
				},
				400,
			);
		}
	});

	// TODO delete when things work, we have a single generic rpc endpoint
	// for (const spec of action_specs) {
	// 	if (DEV) Action_Spec.parse(spec);

	// 	// Select only actions with an HTTP method
	// 	if (!('http_method' in spec)) continue;

	// 	const {method, http_method} = spec;

	// 	const path = parsed_path + method;

	// 	console.log(`Registering API handler: ${http_method} ${path}`);

	// 	const handler: Handler = async (c) => {
	// 		console.log(`[http] <${c.req.url}>`);

	// 		try {
	// 			let params: unknown;

	// 			// Extract parameters based on HTTP method
	// 			if (http_method === 'POST' || http_method === 'PUT' || http_method === 'PATCH') {
	// 				params = await c.req.json();
	// 			}
	// 			// TODO query params for GET, probably a `params`/`json` JSON string

	// 			const jsonrpc_request = JSONRPCRequest.parse({
	// 				jsonrpc: JSONRPC_VERSION,
	// 				id: c.req.header('x-request-id') || create_uuid(), // trusting the client
	// 				method,
	// 				params,
	// 			});

	// 			const response = await zzz_server.jsonrpc_server.process_request(jsonrpc_request);

	// 			if (!response) {
	// 				return c.json({ok: true});
	// 			}

	// 			if ('error' in response) {
	// 				// Map JSON-RPC error to HTTP status
	// 				let status: Http_Status = 500;
	// 				switch (response.error.code) {
	// 					case -32600: // Invalid Request
	// 					case -32602: // Invalid params
	// 						status = 400;
	// 						break;
	// 					case -32601: // Method not found
	// 						status = 404;
	// 						break;
	// 					default:
	// 						if (response.error.code >= -32099 && response.error.code <= -32000) {
	// 							status = 500; // Server error
	// 						}
	// 				}
	// 				return c.json(response, {status});
	// 			}

	// 			return c.json(response.result);
	// 		} catch (error) {
	// 			console.error(`Error processing ${method}:`, error);
	// 			return c.json(
	// 				{
	// 					ok: false,
	// 					message: error instanceof Error ? error.message : API_RESULT_UNKNOWN_ERROR.message,
	// 				},
	// 				error instanceof Api_Error ? error.status : 500,
	// 			);
	// 		}
	// 	};

	// 	// Register the appropriate handler based on HTTP method
	// 	switch (http_method) {
	// 		case 'GET':
	// 			app.get(path, handler);
	// 			break;
	// 		case 'POST':
	// 			app.post(path, handler);
	// 			break;
	// 		case 'PUT':
	// 			app.put(path, handler);
	// 			break;
	// 		case 'DELETE':
	// 			app.delete(path, handler);
	// 			break;
	// 		case 'PATCH':
	// 			app.patch(path, handler);
	// 			break;
	// 		case 'CONNECT':
	// 		case 'HEAD':
	// 		case 'OPTIONS':
	// 		case 'TRACE':
	// 			throw new Api_Error(500, `Unsupported HTTP method ${http_method} for action ${method}`);
	// 		default:
	// 			throw new Unreachable_Error(http_method);
	// 	}
	// }
};
