// @slop

import type {
	Action_Spec,
	Request_Response_Action_Spec,
	Remote_Notification_Action_Spec,
	Local_Call_Action_Spec,
} from '$lib/action_spec.js';
import {to_action_spec_identifier} from '$lib/action_helpers.js';
import type {Action_Method} from '$lib/action_metatypes.js';

/**
 * Utility class to manage and query action specifications.
 * Provides helper methods to get actions by various criteria.
 */
export class Action_Registry {
	specs: Array<Action_Spec>;

	by_method: Map<string, Action_Spec>;

	constructor(specs: Array<Action_Spec>) {
		this.specs = specs;
		this.by_method = new Map(specs.map((spec) => [spec.method, spec]));
	}

	// TODO add maps
	get request_response_specs(): Array<Request_Response_Action_Spec> {
		return this.specs.filter((spec) => spec.kind === 'request_response');
	}

	get remote_notification_specs(): Array<Remote_Notification_Action_Spec> {
		return this.specs.filter((spec) => spec.kind === 'remote_notification');
	}

	get local_call_specs(): Array<Local_Call_Action_Spec> {
		return this.specs.filter((spec) => spec.kind === 'local_call');
	}

	get service_specs(): Array<Action_Spec> {
		// Server actions include both request_response and remote_notification actions
		return [...this.request_response_specs, ...this.remote_notification_specs];
	}

	get client_specs(): Array<Action_Spec> {
		// Client actions are just local_call actions in the new system
		return this.local_call_specs;
	}

	// Methods for deriving lists of action methods
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

	get service_methods(): Array<Action_Method> {
		return this.service_specs.map((spec) => spec.method);
	}

	get client_methods(): Array<Action_Method> {
		return this.client_specs.map((spec) => spec.method);
	}

	get client_to_server_methods(): Array<Action_Method> {
		return this.request_response_methods;
	}

	get server_to_client_methods(): Array<Action_Method> {
		return [...this.request_response_methods, ...this.remote_notification_methods];
	}

	// Utility to get imports needed by generators
	get_schema_imports(): Array<string> {
		return this.specs.map((spec) => to_action_spec_identifier(spec.method));
	}
}
