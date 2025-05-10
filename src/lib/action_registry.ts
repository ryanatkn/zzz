import type {
	Action_Spec,
	Request_Response_Action_Spec,
	Server_Notification_Action_Spec,
	Client_Local_Action_Spec,
} from '$lib/action_spec.js';
import {to_action_spec_identifier} from '$lib/schema_helpers.js';
import type {Action_Method} from '$lib/action_metatypes.js';

/**
 * Utility class to manage and query action specifications.
 * Provides helper methods to get actions by various criteria.
 */
export class Action_Registry {
	specs: Array<Action_Spec>;

	constructor(specs: Array<Action_Spec>) {
		this.specs = specs;
	}

	// TODO add maps
	get request_response_specs(): Array<Request_Response_Action_Spec> {
		return this.specs.filter((spec) => spec.kind === 'request_response');
	}

	get server_notification_specs(): Array<Server_Notification_Action_Spec> {
		return this.specs.filter((spec) => spec.kind === 'server_notification');
	}

	get client_local_specs(): Array<Client_Local_Action_Spec> {
		return this.specs.filter((spec) => spec.kind === 'client_local');
	}

	get service_specs(): Array<Action_Spec> {
		// Service actions include both request_response and server_notification actions
		return [...this.request_response_specs, ...this.server_notification_specs];
	}

	get client_specs(): Array<Action_Spec> {
		// Client actions are just client_local actions in the new system
		return this.client_local_specs;
	}

	// Methods for deriving lists of action methods
	get request_response_methods(): Array<Action_Method> {
		return this.request_response_specs.map((spec) => spec.method);
	}

	get server_notification_methods(): Array<Action_Method> {
		return this.server_notification_specs.map((spec) => spec.method);
	}

	get client_local_methods(): Array<Action_Method> {
		return this.client_local_specs.map((spec) => spec.method);
	}

	get networked_methods(): Array<Action_Method> {
		// Networked actions are request_response actions
		return this.request_response_specs.map((spec) => spec.method);
	}

	get nonnetworked_methods(): Array<Action_Method> {
		// Non-networked actions are server_notifications
		return this.server_notification_specs.map((spec) => spec.method);
	}

	get service_methods(): Array<Action_Method> {
		return this.service_specs.map((spec) => spec.method);
	}

	get client_methods(): Array<Action_Method> {
		return this.client_specs.map((spec) => spec.method);
	}

	// Methods for determining action direction
	// (maintained for compatibility with existing generators)
	get from_client_methods(): Array<Action_Method> {
		// Client-originated actions include request_response and client_local
		return [...this.request_response_methods, ...this.client_local_methods];
	}

	get from_server_methods(): Array<Action_Method> {
		// Server-originated actions are server_notifications
		return this.server_notification_methods;
	}

	// Utility to get imports needed by generators
	get_schema_imports(): Array<string> {
		return this.specs.map((spec) => to_action_spec_identifier(spec.method));
	}
}
