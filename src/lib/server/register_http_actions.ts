import {Hono, type Handler} from 'hono';
import {z} from 'zod';
import {unreachable} from '@ryanatkn/belt/error.js';

import type {Zzz_Server} from '$lib/server/zzz_server.js';
import type {Action_Schema} from '$lib/schemas.js';
import {service_return_to_api_result} from '$lib/server/service.js';
import {API_ROUTE} from '$lib/constants.js';
import {to_api_path} from '$lib/schema_helpers.js';
import {Api_Error} from '$lib/api.js';

export interface Register_Actions_Options {
	app: Hono;
	zzz_server: Zzz_Server; // TODO this is decoupled from the `app` atm but maybe that's unwieldy
	action_schemas: Array<Action_Schema>;
	base_path?: string;
}

/**
 * Registers HTTP endpoints for all service actions in the schema registry.
 */
export const register_http_actions = ({
	app,
	zzz_server,
	action_schemas,
	base_path = API_ROUTE,
}: Register_Actions_Options): void => {
	for (const schema of action_schemas) {
		// Skip client-only actions
		if (schema.type !== 'Service_Action') continue;

		const {name, method} = schema;

		// Generate lowercase API path
		const action_path = to_api_path(name);
		const path = `${base_path}/${action_path}`;

		// Default to POST if no method specified
		if (!method) continue;

		console.log(`Registering API handler: ${method} ${path}`);

		// Create handler based on method
		const handler: Handler = async (c) => {
			try {
				let params;

				// Extract parameters based on HTTP method
				if (method === 'GET') {
					// For GET requests, use query parameters
					const query = c.req.query();
					params = schema.params.parse(query);
				} else {
					// For other methods, use JSON body
					const body = await c.req.json();
					params = schema.params.parse(body);
				}

				// Process the action
				const result = await zzz_server.process_action(name, params);

				// Return API result
				return c.json(service_return_to_api_result(result));
			} catch (error) {
				console.error(`Error processing ${name}:`, error);

				// Return appropriate error response
				if (error instanceof z.ZodError) {
					return c.json(
						{
							ok: false,
							status: 400,
							error: `Invalid parameters for ${name}`,
							details: error.errors,
						},
						400,
					);
				}

				return c.json(
					{
						ok: false,
						status: 500,
						error: `Error processing ${name}`,
						details: error instanceof Error ? error.message : String(error),
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
