import {Logger} from '@ryanatkn/belt/log.js';
import {BROWSER, DEV} from 'esm-env';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';

import type {Actions_Api} from '$lib/action_metatypes.js';
import type {Zzz_App} from '$lib/zzz_app.svelte.js';
import {create_jsonrpc_notification, create_jsonrpc_request} from '$lib/jsonrpc_helpers.js';
import {create_uuid} from '$lib/zod_helpers.js';
import {Action} from '$lib/action.svelte.js';
import type {Action_Input} from './action_types.js';

const log = new Logger();

// TODO @api refactor, extract a clear abstraction, maybe `Action_Invocation`,
// can have multiple mutation contexts, covers the whole sync/async function call wrapper

// TODO think about transactions, snapshotting

export const create_actions_api = (app: Zzz_App): Actions_Api =>
	new Proxy(Object.create(null), {
		get: (_target, method: keyof Actions_Api) => (input: Action_Input) => {
			// TODO BLOCK `log.debug` isn't formatting the output correctly, shouldn't use console here
			console.log(...to_logged_args(method, input));

			const spec = app.action_registry.by_method.get(method);
			if (!spec) {
				throw new Error(`missing action spec for method '${method}'`);
			}

			const action = new Action({app, json: {method}});

			// Handle different action kinds with their appropriate phases
			switch (spec.kind) {
				case 'request_response': {
					const request = create_jsonrpc_request(method, input, create_uuid());
					console.log(`[actions_api] request_action_message`, request);

					action.add_request(request);

					// Handle request phase
					app.handle(method, input, null, 'send_request', request, log);

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
						app.handle(method, input, result, 'receive_response', response, log);

						return result;
					});
				}

				case 'remote_notification': {
					const notification = create_jsonrpc_notification(method, input);

					action.add_notification(notification);

					return app.handle(method, input, null, 'send', notification, log);
				}

				case 'local_call': {
					return app.handle(method, input, null, 'execute', null, log);
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
