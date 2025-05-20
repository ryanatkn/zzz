import {Logger} from '@ryanatkn/belt/log.js';
import {BROWSER, DEV} from 'esm-env';

import type {Actions_Api} from '$lib/action_metatypes.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import {create_mutation_context} from '$lib/mutation.js';
import {to_action_message_type} from '$lib/action_helpers.js';
import type {Api_Request_Response_Flag} from '$lib/api.js';
import {create_jsonrpc_request} from '$lib/jsonrpc_helpers.js';
import {create_uuid} from '$lib/zod_helpers.js';
import type {JSONRPCRequest} from '$lib/jsonrpc.js';

const log = new Logger();

// TODO think about transactions, snapshotting

export const create_actions_api = (zzz: Zzz): Actions_Api =>
	new Proxy(Object.create(null), {
		get: (_target, method: keyof Actions_Api) => (params: any) => {
			// TODO BLOCK `log.debug` isn't formatting the output correctly, shouldn't use console here
			console.log(...to_logged_args(method, params));

			const spec = zzz.action_registry.by_method.get(method);
			if (!spec) {
				throw Error(`missing action spec for method '${method}'`);
			}

			const mutate = (
				result: unknown,
				request_response: Api_Request_Response_Flag,
				jsonrpc_message: JSONRPCRequest,
			) => {
				console.log(`mutate`, method, result, request_response);
				const {ctx, flush_after_mutation} = create_mutation_context(
					zzz,
					method,
					params,
					result,
					request_response,
					jsonrpc_message,
				);
				const message_type = to_action_message_type(method, request_response);
				console.log(`message_type`, message_type);
				const mutation = zzz.mutations[message_type];
				if (!mutation) {
					log.warn(`missing mutation for action '${method}'`);
				}
				const mutated = mutation?.(ctx);
				void flush_after_mutation(); // not awaited
				return mutated;
			};

			const jsonrpc_message = create_jsonrpc_request(method, params, create_uuid());

			// Request-response actions have special handling,
			// each such method has a `_request` and `_response` type variant.
			if (spec.kind === 'request_response') {
				mutate(undefined, 'request', jsonrpc_message);

				// Avoiding `await` for compatibility with sync actions
				return zzz.api_client
					.send(jsonrpc_message)
					.then((result) => mutate(result, 'response', jsonrpc_message));
			}

			// Handle non-request-response actions synchronously
			return mutate(undefined, null, jsonrpc_message);
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
