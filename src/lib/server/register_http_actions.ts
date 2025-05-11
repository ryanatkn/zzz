import {Hono, type Handler} from 'hono';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';
import {DEV} from 'esm-env';

import type {Zzz_Server} from '$lib/server/zzz_server.js';
import {Action_Spec} from '$lib/action_spec.js';
import {API_ROUTE} from '$lib/constants.js';
import {Api_Error, Http_Status} from '$lib/api.js';
import {create_uuid, Path_With_Trailing_Slash} from '$lib/zod_helpers.js';
import {JSONRPC_VERSION, JSONRPCRequest} from '$lib/jsonrpc.js';

export interface Register_Actions_Options {
	app: Hono;
	zzz_server: Zzz_Server;
	action_specs?: Array<Action_Spec>;
	base_path?: string;
}

/**
 * Registers HTTP endpoints for all service actions in the schema registry.
 */
export const register_http_actions = ({
	app,
	zzz_server,
	action_specs = zzz_server.action_specs,
	base_path = API_ROUTE,
}: Register_Actions_Options): void => {
	// Register a single JSON-RPC endpoint that handles all methods
	const parsed_base_path = Path_With_Trailing_Slash.parse(base_path);
	const jsonrpc_path = parsed_base_path + 'jsonrpc';

	console.log(`Registering JSON-RPC endpoint: POST ${jsonrpc_path}`);

	app.post(jsonrpc_path, async (c) => {
		console.log(`[http] <${c.req.url}>`);
		try {
			const request_data = await c.req.json();
			const response = await zzz_server.jsonrpc_server.process_request(request_data);

			// If it's a notification, there's no response
			if (!response) {
				return c.json({ok: true});
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

	// Also register traditional RESTful endpoints for backward compatibility
	// and for services that prefer a REST-style API
	for (const spec of action_specs) {
		if (DEV) Action_Spec.parse(spec);

		// Select only actions with an HTTP method
		if (!('http_method' in spec)) continue;

		const {method, http_method} = spec;

		const path = parsed_base_path + method;

		console.log(`Registering API handler: ${http_method} ${path}`);

		const handler: Handler = async (c) => {
			console.log(`[http] <${c.req.url}>`);

			try {
				let params: unknown;

				// Extract parameters based on HTTP method
				if (http_method === 'POST' || http_method === 'PUT' || http_method === 'PATCH') {
					params = await c.req.json();
				}
				// TODO query params for GET, probably a `params`/`json` JSON string

				const jsonrpc_request = JSONRPCRequest.parse({
					jsonrpc: JSONRPC_VERSION,
					id: c.req.header('x-request-id') || create_uuid(), // trusting the client
					method,
					params,
				});

				const response = await zzz_server.jsonrpc_server.process_request(jsonrpc_request);

				if (!response) {
					return c.json({ok: true});
				}

				if ('error' in response) {
					// Map JSON-RPC error to HTTP status
					let status: Http_Status = 500;
					switch (response.error.code) {
						case -32600: // Invalid Request
						case -32602: // Invalid params
							status = 400;
							break;
						case -32601: // Method not found
							status = 404;
							break;
						default:
							if (response.error.code >= -32099 && response.error.code <= -32000) {
								status = 500; // Server error
							}
					}
					return c.json(response, {status});
				}

				return c.json(response.result);
			} catch (error) {
				console.error(`Error processing ${method}:`, error);
				return c.json(
					{
						ok: false,
						message: error instanceof Error ? error.message : 'Unknown error',
					},
					error instanceof Api_Error ? error.status : 500,
				);
			}
		};

		// Register the appropriate handler based on HTTP method
		switch (http_method) {
			case 'GET':
				app.get(path, handler);
				break;
			case 'POST':
				app.post(path, handler);
				break;
			case 'PUT':
				app.put(path, handler);
				break;
			case 'DELETE':
				app.delete(path, handler);
				break;
			case 'PATCH':
				app.patch(path, handler);
				break;
			case 'CONNECT':
			case 'HEAD':
			case 'OPTIONS':
			case 'TRACE':
				throw new Api_Error(500, `Unsupported HTTP method ${http_method} for action ${method}`);
			default:
				throw new Unreachable_Error(http_method);
		}
	}
};
