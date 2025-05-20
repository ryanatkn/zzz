import {Logger} from '@ryanatkn/belt/log.js';
import {BROWSER, DEV} from 'esm-env';

import type {Actions_Api} from '$lib/action_metatypes.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import {create_mutation_context} from '$lib/mutation.js';

const log = new Logger();

// TODO think about transactions, snapshotting

export const create_actions_api = (zzz: Zzz): Actions_Api =>
	new Proxy(Object.create(null), {
		get: (_target, method: keyof Actions_Api) => (params: unknown) => {
			log.debug(...to_logged_args(method, params));

			const spec = zzz.action_registry.by_method.get(method);
			if (!spec) {
				throw Error(`missing action spec for method '${method}'`);
			}

			const mutation = zzz.mutations[method];
			if (!mutation) {
				throw Error(`missing mutation for action '${method}'`);
			}

			const mutate = (result: unknown) => {
				const {ctx, flush_after_mutation} = create_mutation_context(zzz, method, params, result);
				const mutated = mutation(ctx);
				void flush_after_mutation(); // not awaited
				return mutated;
			};

			// Request-response actions have special handling,
			// each such method has a `_request` and `_response` type variant.
			if (spec.kind === 'request_response') {
				return zzz.api_client.send_action(method, params).then((result) => {
					if (!result || !('then' in result)) {
						return mutate(result);
					}
					return result.then((result) => {
						zzz.api_client.receive_incoming_message(method, params, action.id);
						mutate(result);
					});
				});
			}

			// Handle non-request-response actions synchronously
			return mutate(undefined);

			// const mutate = (result: unknown) => {
			// 	// TODO dynamic registry? maybe with an API not a plain object?
			// 	const mutation = lookup_mutation(method);
			// 	if (!mutation) {
			// 		// console.warn('unknown message name, ignoring:', message.method, message);
			// 		return; // Ignore messages with no mutations
			// 	}

			// 	const mutation_context = create_mutation_context(
			// 		this,
			// 		message.method,
			// 		message, // For client actions, params are the full message
			// 		undefined, // Result is undefined for sending
			// 	);

			// 	// TODO think about before/after
			// 	// TODO @many try/catch?
			// 	const result = mutation(mutation_context.ctx as unknown as any); // TODO type ?
			// 	mutation_context.flush_after_mutation();
			// 	return result;
			// };

			// const returned = zzz.api_client.send_action(method, params);
			// if (!returned || !('then' in returned)) {
			// 	return mutate(returned);
			// }
			// return returned.then(mutate);

			// console.log('[ws] sending message', message);
			// // TODO BLOCK Action_Message_From_Client ? parse in dev?
			// const m: JSONRPCMessage = {
			// 	// TODO use helpers
			// 	// jsonrpc: '2.0',
			// 	id: message.id || create_uuid(),
			// 	method: message.method,
			// 	params: message.params as any,
			// };

			// console.log(`constructed m`, m);
			// zzz.api_client.send_action;

			// // TODO dynamic registry? maybe with an API not a plain object?
			// const mutation = send_mutations?.[message.method]; // TODO think about before/after
			// if (!mutation) {
			// 	// console.warn('unknown message name, ignoring:', message.method, message);
			// 	return; // Ignore messages with no mutations
			// }

			// const mutation_context = create_mutation_context(
			// 	this,
			// 	message.method,
			// 	message, // For client actions, params are the full message
			// 	undefined, // Result is undefined for sending
			// );

			// // TODO @many try/catch?
			// const result = mutation(mutation_context.ctx as unknown as any); // TODO type ?
			// mutation_context.flush_after_mutation();
			// return result;

			// console.log(`[ws] received message`, message);

			//       // TODO BLOCK Action_Message_From_Server ? parse in dev?
			//       const m: JSONRPCMessage = {
			//         id: message.id,
			//         created: get_datetime_now(),
			//         method: message.method,
			//         params: message.params,
			//       };

			//       // Handle the message based on its method
			//       this.api_client.handle_incoming_message(message);

			//       const mutation = receive_mutations?.[message.method];
			//       if (!mutation) {
			//         // console.warn('unknown message type, ignoring:', message.type, message);
			//         return; // Ignore messages with no mutations
			//       }

			//       const mutation_context = create_mutation_context(
			//         this,
			//         message.method,
			//         message, // For received actions, params are the full message
			//         // TODO BLOCK delete this?
			//         {
			//           ok: true,
			//           status: 200, // TODO BLOCK @many JSON-RPC need to forward status, use JSON-RPC like MCP
			//           value: message,
			//         },
			//       );

			//       // TODO @many try/catch?
			//       const result = mutation(mutation_context.ctx as unknown as any); // TODO type ?
			//       mutation_context.flush_after_mutation();
			//       return result;
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
