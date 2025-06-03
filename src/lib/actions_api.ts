import {Logger} from '@ryanatkn/belt/log.js';
import {BROWSER, DEV} from 'esm-env';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';

import type {Actions_Api} from '$lib/action_metatypes.js';
import type {Zzz_App} from '$lib/zzz_app.svelte.js';
import {Client_Action_Context} from '$lib/client_action_event.js';
import {create_jsonrpc_notification, create_jsonrpc_request} from '$lib/jsonrpc_helpers.js';
import {create_uuid} from '$lib/zod_helpers.js';
import type {Jsonrpc_Singular_Message} from '$lib/jsonrpc.js';
import type {Action_Phase} from '$lib/action_types.js';
import {Action} from '$lib/action.svelte.js';

const log = new Logger();

// TODO @api refactor, extract a clear abstraction, maybe `Action_Invocation`,
// can have multiple mutation contexts, covers the whole sync/async function call wrapper

// TODO think about transactions, snapshotting

export const create_actions_api = (app: Zzz_App): Actions_Api =>
	new Proxy(Object.create(null), {
		get: (_target, method: keyof Actions_Api) => (params: any) => {
			// TODO BLOCK `log.debug` isn't formatting the output correctly, shouldn't use console here
			console.log(...to_logged_args(method, params));

			const spec = app.action_registry.by_method.get(method);
			if (!spec) {
				throw new Error(`missing action spec for method '${method}'`);
			}

			const action = new Action({app, json: {method}});

			const handle_message = (
				result: any | null, // TODO @api type
				phase: Action_Phase,
				jsonrpc_message: Jsonrpc_Singular_Message | null,
			): unknown => {
				console.log('[actions_api] handle_message', method, phase, result);
				const event = new Client_Action_Context(
					app,
					method,
					phase,
					params,
					result,
					jsonrpc_message,
				);
				console.log(`[actions_api] event`, event);

				const handlers_by_phase = app.action_handlers[method];
				if (!handlers_by_phase) {
					log.error(`missing handlers for action ${method}`);
					return;
				}

				const handler = (handlers_by_phase as any)[phase]; // TODO @api type

				if (!handler) {
					log.error(`missing handler for action ${method}.${phase}`);
					return;
				}

				event.handle(handler);

				return event.result;
			};

			// Handle different action kinds with their appropriate phases
			switch (spec.kind) {
				case 'request_response': {
					const request = create_jsonrpc_request(method, params, create_uuid());
					console.log(`[actions_api] request_action_message`, request);

					action.add_request(request);

					// Handle request phase
					handle_message(null, 'send_request', request);

					// Avoiding `await` for compatibility with sync actions
					return app.api_client.send(request).then((response) => {
						console.log(`[actions_api] response`, response);

						// Check if it's an error response
						if ('error' in response) {
							console.error(`response error`, response);
							// TODO BLOCK @api should this throw or just log?
							// throw new Error(`JSON-RPC error ${response.error.code}: ${response.error.message}`);
							return;
						}

						action.add_response(response);

						const {result} = response;
						handle_message(result, 'receive_response', response);

						return result;
					});
				}

				case 'remote_notification': {
					const notification = create_jsonrpc_notification(method, params);

					action.add_notification(notification);

					return handle_message(null, 'send', notification);
				}

				case 'local_call': {
					return handle_message(null, 'execute', null);
				}

				default:
					throw new Unreachable_Error(spec);
			}
		},
	});

const to_logged_args = (method: string, params: unknown): Array<any> => {
	const args = to_logged_method(method);
	if (params !== undefined) args.push(params); // print null but not undefined}
	return args;
};

const to_logged_method = (method: string): Array<any> =>
	BROWSER && DEV
		? [
				'%c[api.%c' + method + '%c]',
				'color: gray',
				'color: magenta; font-weight: bold',
				'color: gray',
			]
		: ['[api.' + method + ']'];
