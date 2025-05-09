import {Hono, type Handler} from 'hono';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';

import type {Zzz_Server} from '$lib/server/zzz_server.js';
import type {Action_Spec} from '$lib/schemas.js';
import {service_return_to_api_result} from '$lib/server/service.js';
import {API_ROUTE} from '$lib/constants.js';
import {Api_Error, to_failed_api_result} from '$lib/api.js';
import {Path_With_Trailing_Slash} from '$lib/zod_helpers.js';

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
	action_specs = zzz_server.action_specs,
	base_path = API_ROUTE,
}: Register_Actions_Options): void => {
	for (const spec of action_specs) {
		// Select only actions with an HTTP method
		if (!('http_method' in spec)) continue;

		const {method, http_method} = spec;

		if (!http_method) continue;

		const parsed_base_path = Path_With_Trailing_Slash.parse(base_path); // let it fail right?

		const path = parsed_base_path + method;

		// TODO BLOCK remove logging
		console.log(`Registering API handler: ${http_method} ${path}`);

		const handler: Handler = async (c) => {
			console.log(`[http] <${c.req.url}>`);

			try {
				let params: unknown = null;

				// Extract parameters based on HTTP method
				if (http_method === 'POST' || http_method === 'PUT' || http_method === 'PATCH') {
					params = await c.req.json();
				}

				// Process the action using the unified method
				const service_result = await zzz_server.process_action(method, params);

				// Convert to API result format and return JSON response
				const api_result = service_return_to_api_result(service_result);
				console.log(`api_result`, api_result);
				return c.json(api_result);
			} catch (error) {
				console.error(`Error processing ${method}:`, error);
				const failed_result = to_failed_api_result(error);
				return c.json(failed_result, failed_result.status);
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
