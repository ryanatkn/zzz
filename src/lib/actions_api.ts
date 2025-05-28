import {Logger} from '@ryanatkn/belt/log.js';
import {BROWSER, DEV} from 'esm-env';

import type {Actions_Api} from '$lib/action_metatypes.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import {Client_Action_Context} from '$lib/client_action_event.js';
import {create_jsonrpc_request} from '$lib/jsonrpc_helpers.js';
import {create_uuid} from '$lib/zod_helpers.js';
import {to_action_message, to_action_message_type} from '$lib/action_helpers.js';
import type {Action_Message_Union} from '$lib/action_collections.js';
import type {Jsonrpc_Notification, Jsonrpc_Request} from '$lib/jsonrpc.js';
import type {Api_Request_Response_Flag} from '$lib/api.js';

const log = new Logger();

// TODO refactor, extract a clear abstraction, maybe `Action_Invocation_Context`,
// can have multiple mutation contexts, covers the whole sync/async function call wrapper

// TODO think about transactions, snapshotting

export const create_actions_api = (zzz: Zzz): Actions_Api =>
	new Proxy(Object.create(null), {
		get: (_target, method: keyof Actions_Api) => (params: any) => {
			// TODO BLOCK `log.debug` isn't formatting the output correctly, shouldn't use console here
			console.log(...to_logged_args(method, params));

			const spec = zzz.action_registry.by_method.get(method);
			if (!spec) {
				throw new Error(`missing action spec for method '${method}'`);
			}

			const handle = (
				result: any | null, // TODO @api type
				request_response_flag: Api_Request_Response_Flag,
				action_message: Action_Message_Union,
				jsonrpc_message: Jsonrpc_Request | Jsonrpc_Notification | null,
			) => {
				console.log('\n\n\n\n\n\n\n\n[actions_api] mutate', method, result, request_response_flag);
				const event = new Client_Action_Context(
					zzz,
					method,
					params,
					result,
					request_response_flag,
					action_message,
					jsonrpc_message,
				);
				console.log(`[actions_api] message_type`, event.action_message.type);
				console.log(`[actions_api] event`, event);

				const handler = zzz.mutations[event.action_message.type];
				if (!handler) {
					log.warn(`missing mutation for action '${method}'`);
				}

				if (handler) {
					event.handle(handler);
				}

				return event.result;
			};

			const request_jsonrpc_message = create_jsonrpc_request(method, params, create_uuid());

			const request_action_message_type = to_action_message_type(
				method,
				spec.kind === 'request_response' ? 'request' : null,
			);
			const request_action_message = to_action_message(
				request_action_message_type,
				params as unknown as any, // TODO type
				request_jsonrpc_message,
			);
			zzz.actions.add_message(request_action_message);
			console.log(`[actions_api] request_action_message`, request_action_message);

			// `request_response` actions have special handling,
			// each such method has a `_request` and `_response` type variant.
			if (spec.kind === 'request_response') {
				handle(null, 'request', request_action_message, request_jsonrpc_message);

				// Avoiding `await` for compatibility with sync actions
				return zzz.api_client.send(request_jsonrpc_message).then((response) => {
					console.log(`[actions_api] response`, response);

					// Check if it's an error response
					if ('error' in response) {
						console.error(`response error`, response);
						// TODO BLOCK @api should this throw or just log?
						// throw new Error(`JSON-RPC error ${response.error.code}: ${response.error.message}`);
						return;
					}

					const response_jsonrpc_message = response;
					const response_action_message_type = to_action_message_type(method, 'response');
					console.log(`[actions_api] response_action_message_type`, response_action_message_type);
					console.log(
						`[actions_api] response_jsonrpc_message.result`,
						response_jsonrpc_message.result,
					);
					console.log(`[actions_api] response_jsonrpc_message`, response_jsonrpc_message);
					const response_action_message = to_action_message(
						response_action_message_type,
						response_jsonrpc_message.result as unknown as any, // TODO type
						response_jsonrpc_message,
					);
					console.log(`[actions_api] response_action_message`, response_action_message);
					zzz.actions.add_message(response_action_message);

					const result = response_jsonrpc_message.result;
					handle(result, 'response', response_action_message, response_jsonrpc_message);

					// Return the result value directly
					return result;
				});
			}

			// Handle non-`request_response` actions synchronously
			return handle(null, null, request_action_message, request_jsonrpc_message);
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
