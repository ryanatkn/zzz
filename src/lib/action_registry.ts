// @slop

import type {
	Action_Spec,
	Request_Response_Action_Spec,
	Remote_Notification_Action_Spec,
	Local_Call_Action_Spec,
} from '$lib/action_spec.js';
import {to_action_spec_identifier} from '$lib/action_helpers.js';
import type {Action_Method} from '$lib/action_metatypes.js';

// TODO use derived or `??=` in lazy getters for memoization

/**
 * Utility class to manage and query action specifications.
 * Provides helper methods to get actions by various criteria.
 */
export class Action_Registry {
	specs: Array<Action_Spec>;

	constructor(specs: Array<Action_Spec>) {
		this.specs = specs;
	}

	get spec_by_method(): Map<string, Action_Spec> {
		return new Map(this.specs.map((spec) => [spec.method, spec]));
	}

	get request_response_specs(): Array<Request_Response_Action_Spec> {
		return this.specs.filter((spec) => spec.kind === 'request_response');
	}

	get remote_notification_specs(): Array<Remote_Notification_Action_Spec> {
		return this.specs.filter((spec) => spec.kind === 'remote_notification');
	}

	get local_call_specs(): Array<Local_Call_Action_Spec> {
		return this.specs.filter((spec) => spec.kind === 'local_call');
	}

	// TODO @api piece this apart? maybe sender/receiver so you can express server->server calls?
	get server_specs(): Array<Action_Spec> {
		return this.specs.filter((spec) => spec.kind !== 'local_call');
	}

	get client_specs(): Array<Action_Spec> {
		return this.specs;
	}

	get server_to_client_specs(): Array<Action_Spec> {
		return this.specs.filter((spec) => spec.initiator === 'server' || spec.initiator === 'both');
	}

	get client_to_server_specs(): Array<Action_Spec> {
		return this.specs.filter((spec) => spec.initiator === 'client' || spec.initiator === 'both');
	}

	get methods(): Array<Action_Method> {
		return this.specs.map((spec) => spec.method);
	}

	get request_response_methods(): Array<Action_Method> {
		return this.request_response_specs.map((spec) => spec.method);
	}

	get remote_notification_methods(): Array<Action_Method> {
		return this.remote_notification_specs.map((spec) => spec.method);
	}

	get local_call_methods(): Array<Action_Method> {
		return this.local_call_specs.map((spec) => spec.method);
	}

	get networked_methods(): Array<Action_Method> {
		// Networked actions are request_response actions
		return this.request_response_specs.map((spec) => spec.method);
	}

	get nonnetworked_methods(): Array<Action_Method> {
		const {networked_methods} = this;
		// Non-networked actions are remote_notifications
		return this.remote_notification_specs
			.map((spec) => spec.method)
			.filter((method) => !networked_methods.includes(method));
	}

	get server_methods(): Array<Action_Method> {
		return this.server_specs.map((spec) => spec.method);
	}

	get client_methods(): Array<Action_Method> {
		return this.client_specs.map((spec) => spec.method);
	}

	get client_to_server_methods(): Array<Action_Method> {
		return this.client_to_server_specs.map((spec) => spec.method);
	}

	get server_to_client_methods(): Array<Action_Method> {
		return this.server_to_client_specs.map((spec) => spec.method);
	}

	get_schema_imports(): Array<string> {
		return this.specs.map((spec) => to_action_spec_identifier(spec.method));
	}
}
