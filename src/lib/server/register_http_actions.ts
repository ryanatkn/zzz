import {Hono} from 'hono';
import {z} from 'zod';

import type {Zzz_Server} from '$lib/server/zzz_server.js';
import type {Action_Schema} from '$lib/schemas.js';
import {service_return_to_api_result} from '$lib/server/service.js';
import {API_ROUTE} from '$lib/constants.js';
import {to_api_path} from '$lib/schema_helpers.js';

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

		// Generate lowercase API path
		const action_path = to_api_path(schema.name);
		const path = `${base_path}/${action_path}`;

		console.log(`Registering API handler: ${path}`);

		app.post(path, async (c) => {
			try {
				// Parse request body
				const body = await c.req.json();

				// Validate parameters
				const params = schema.params.parse(body);

				// Process the action
				const result = await zzz_server.process_action(schema.name, params);

				// Return API result
				return c.json(service_return_to_api_result(result));
			} catch (error) {
				console.error(`Error processing ${schema.name}:`, error);

				// Return appropriate error response
				if (error instanceof z.ZodError) {
					return c.json(
						{
							ok: false,
							status: 400,
							error: `Invalid parameters for ${schema.name}`,
							details: error.errors,
						},
						400,
					);
				}

				return c.json(
					{
						ok: false,
						status: 500,
						error: `Error processing ${schema.name}`,
						details: error instanceof Error ? error.message : String(error),
					},
					500,
				);
			}
		});
	}
};
