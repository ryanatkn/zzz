// @slop claude_opus_4
// actions_api.ts

// import {Logger} from '@ryanatkn/belt/log.js';
import {BROWSER, DEV} from 'esm-env';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';

import type {Action_Method, Actions_Api} from '$lib/action_metatypes.js';
import type {Zzz_App} from '$lib/zzz_app.svelte.js';
import {Action} from '$lib/action.svelte.js';
import type {Action_Input} from '$lib/action_types.js';
import {create_action_event} from '$lib/action_event.js';
import type {
	Request_Response_Action_Event_Data,
	Remote_Notification_Action_Event_Data,
} from '$lib/action_event_types.js';

// TODO see below, logger is broken with syntax styling
// const log = new Logger();

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
			const action_event = create_action_event(app, spec, input);
			action.action_event = action_event;

			switch (spec.kind) {
				case 'request_response': {
					action_event.parse();

					return action_event.handle_async().then(async () => {
						if (
							action_event.data.step === 'handled' &&
							action_event.data.phase === 'send_request'
						) {
							app.actions.add(action);

							// TODO BLOCK @api try to make these use narrowing
							// TypeScript knows this is the right phase/step combination
							const data = action_event.data as Extract<
								Request_Response_Action_Event_Data,
								{phase: 'send_request'; step: 'handled'}
							>;
							const response = await app.api_client.send(data.request);
							console.log(`[actions_api] response`, response);

							// Transition to receive_response phase
							action_event.transition_to_phase('receive_response');
							// TODO seems hacky
							// Manually set the response data
							action_event.data = {
								...action_event.data,
								response,
								output: 'result' in response ? response.result : undefined,
							} as any; // Complex state transition requires cast

							await action_event.parse().handle_async();

							if ('error' in response) {
								// TODO API for callers to access the current error?
								console.error(`response error`, response);
								return;
							}

							return action_event.output;
						}
						throw new Error('Failed to create request');
					});
				}

				case 'remote_notification': {
					action_event.parse();

					return action_event.handle_async().then(() => {
						if (action_event.data.step === 'handled' && action_event.data.phase === 'send') {
							app.actions.add(action);
							// TypeScript knows this is the right phase/step combination
							const data = action_event.data as Extract<
								Remote_Notification_Action_Event_Data,
								{phase: 'send'; step: 'handled'}
							>;
							return app.api_client.send(data.notification);
						}
						throw new Error('Failed to create notification');
					});
				}

				case 'local_call': {
					action_event.parse();
					app.actions.add(action);

					if (spec.async) {
						return action_event.handle_async().then(() => action_event.output);
					} else {
						action_event.handle_sync();
						return action_event.output;
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
