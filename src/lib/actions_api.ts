// @slop
// actions_api.ts

import {Logger} from '@ryanatkn/belt/log.js';
import {BROWSER, DEV} from 'esm-env';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';

import type {Action_Method, Actions_Api} from '$lib/action_metatypes.js';
import type {Zzz_App} from '$lib/zzz_app.svelte.js';
import {Action} from '$lib/action.svelte.js';
import type {Action_Input} from '$lib/action_types.js';
import {create_frontend_action_event} from '$lib/frontend_action_event.js';
import type {
	Frontend_Request_Response_Action_Event,
	Frontend_Remote_Notification_Action_Event,
	Frontend_Local_Call_Action_Event,
} from '$lib/frontend_action_event.js';

const log = new Logger();

// TODO @api refactor, extract a clear abstraction, maybe `Action_Invocation`,
// can have multiple mutation contexts, covers the whole sync/async function call wrapper

// TODO think about transactions, snapshotting

export const create_actions_api = (app: Zzz_App): Actions_Api =>
	new Proxy(Object.create(null), {
		get: (_target, method: Action_Method) => (input: Action_Input) => {
			// TODO BLOCK `log.debug` isn't formatting the output correctly, shouldn't use console here
			console.log(...to_logged_args(method, input));

			const spec = app.action_registry.spec_by_method.get(method);
			if (!spec) {
				throw new Error(`missing action spec for method '${method}'`);
			}

			const action = new Action({app, json: {method}});
			const action_event = create_frontend_action_event(app, spec, input);
			action.action_event = action_event;

			switch (spec.kind) {
				case 'request_response': {
					const event = action_event as Frontend_Request_Response_Action_Event;
					event.parse();

					return event.handle_async().then(async () => {
						if (event.data.step === 'handled' && event.data.phase === 'send_request') {
							app.actions.add(action);

							const response = await app.api_client.send(event.data.request);
							console.log(`[actions_api] response`, response);

							event.transition_to_phase('receive_response');
							event.data = {
								...event.data,
								response,
								output: 'result' in response ? response.result : undefined,
							};

							await event.parse().handle_async();

							if ('error' in response) {
								// TODO API for callers to access the current error?
								console.error(`response error`, response);
								return;
							}

							if (event.data.phase === 'receive_response' && 'output' in event.data) {
								return event.data.output; // TODO is this if guard correct? see elsewhere too
							}
						}
						throw new Error('Failed to create request');
					});
				}

				case 'remote_notification': {
					const event = action_event as Frontend_Remote_Notification_Action_Event;
					event.parse();

					return event.handle_async().then(() => {
						if (event.data.step === 'handled' && event.data.phase === 'send') {
							app.actions.add(action);
							return app.api_client.send(event.data.notification);
						}
						throw new Error('Failed to create notification');
					});
				}

				case 'local_call': {
					const event = action_event as Frontend_Local_Call_Action_Event;
					event.parse();
					app.actions.add(action);

					if (spec.async) {
						return event.handle_async().then(() => {
							if (event.data.step === 'handled' && 'output' in event.data) {
								return event.data.output;
							}
						});
					} else {
						event.handle_sync();
						if (event.data.step === 'handled' && 'output' in event.data) {
							return event.data.output;
						}
					}
				}

				default:
					throw new Unreachable_Error(spec);
			}
		},
	});

const to_logged_args = (method: string, params: unknown): Array<any> => {
	const args = to_logged_method(method);
	if (params !== undefined) args.push(params);
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
