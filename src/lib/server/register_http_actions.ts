import {Hono, type Handler} from 'hono';
import {unreachable} from '@ryanatkn/belt/error.js';

import type {Zzz_Server} from '$lib/server/zzz_server.js';
import type {Action_Spec} from '$lib/schemas.js';
import {service_return_to_api_result} from '$lib/server/service.js';
import {API_ROUTE} from '$lib/constants.js';
import {to_api_path} from '$lib/schema_helpers.js';
import {Api_Error} from '$lib/api.js';

export interface Register_Actions_Options {
	app: Hono;
	zzz_server: Zzz_Server; // TODO this is decoupled from the `app` atm but maybe that's unwieldy
	action_specs: Array<Action_Spec>;
	base_path?: string;
}

/**
 * Registers HTTP endpoints for all service actions in the schema registry.
 */
export const register_http_actions = ({
	app,
	zzz_server,
	action_specs,
	base_path = API_ROUTE,
}: Register_Actions_Options): void => {
	for (const spec of action_specs) {
		// Register only service actions
		if (spec.type !== 'Service_Action') continue;

		const {name, method} = spec;

		// Generate lowercase API path
		const action_path = to_api_path(name);
		const path = `${base_path}/${action_path}`;

		if (!method) continue;

		console.log(`Registering API handler: ${method} ${path}`);

		const handler: Handler = async (c) => {
			console.log(`HANDLER c`, c);
			try {
				let params: unknown;

				// TODO this too for get? `const query = c.req.query();`
				// Extract parameters based on HTTP method
				if (method === 'POST' || method === 'PUT' || method === 'PATCH') {
					params = await c.req.json();
				}

				const service_result = await zzz_server.process_action(name, params);

				const api_result = service_return_to_api_result(service_result);

				return c.json(api_result);
			} catch (error) {
				console.error(`Error processing ${name}:`, error);

				if (error instanceof Api_Error) {
					return c.json(
						// TODO @many JSON-RPC types and parsing in DEV
						{
							ok: false,
							status: error.status,
							error: error.message,
						},
						400,
					);
				}

				return c.json(
					// TODO @many JSON-RPC types and parsing in DEV
					{
						ok: false,
						status: 500,
						error: `Unknownn error processing ${name}`,
					},
					500,
				);
			}
		};

		// Register the appropriate handler based on HTTP method
		switch (method) {
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
				throw new Api_Error(500, `Unsupported HTTP method ${method} for action ${name}`);
			default:
				unreachable(method);
		}
	}
};
