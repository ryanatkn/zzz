import type {
	Action_Spec,
	Request_Response_Action_Spec,
	Notification_Action_Spec,
	Client_Local_Action_Spec,
} from '$lib/action_spec.js';
import {to_action_spec_identifier} from '$lib/schema_helpers.js';

/**
 * Utility class to manage and query action specifications.
 * Provides helper methods to get actions by various criteria.
 */
export class Action_Registry {
	specs: Array<Action_Spec>;

	constructor(specs: Array<Action_Spec>) {
		this.specs = specs;
	}

	// Methods to get actions by type with proper typing
	get request_response_specs(): Array<Request_Response_Action_Spec> {
		return this.specs.filter(
			(spec) => spec.type === 'request_response',
		) as Array<Request_Response_Action_Spec>;
	}

	get notification_specs(): Array<Notification_Action_Spec> {
		return this.specs.filter(
			(spec) => spec.type === 'notification',
		) as Array<Notification_Action_Spec>;
	}

	get client_local_specs(): Array<Client_Local_Action_Spec> {
		return this.specs.filter(
			(spec) => spec.type === 'client_local',
		) as Array<Client_Local_Action_Spec>;
	}

	// For backward compatibility with existing code
	get service_specs(): Array<Action_Spec> {
		// Service actions include both request_response and notification actions
		return this.specs.filter(
			(spec) => spec.type === 'request_response' || spec.type === 'notification',
		);
	}

	get client_specs(): Array<Action_Spec> {
		// Client actions are just client_local actions in the new system
		return this.client_local_specs;
	}

	// Methods for deriving lists of action methods
	get request_response_methods(): Array<string> {
		return this.request_response_specs.map((spec) => spec.method);
	}

	get notification_methods(): Array<string> {
		return this.notification_specs.map((spec) => spec.method);
	}

	get client_local_methods(): Array<string> {
		return this.client_local_specs.map((spec) => spec.method);
	}

	get networked_methods(): Array<string> {
		// Networked actions are request_response actions
		return this.request_response_specs.map((spec) => spec.method);
	}

	get nonnetworked_methods(): Array<string> {
		// Non-networked actions are notifications
		return this.notification_specs.map((spec) => spec.method);
	}

	get service_methods(): Array<string> {
		return this.service_specs.map((spec) => spec.method);
	}

	get client_methods(): Array<string> {
		return this.client_specs.map((spec) => spec.method);
	}

	// Methods for determining action direction
	// (maintained for compatibility with existing generators)
	get from_client_methods(): Array<string> {
		// In the new system, client-originated actions include request_response and client_local
		return [...this.request_response_methods, ...this.client_local_methods];
	}

	get from_server_methods(): Array<string> {
		// In the new system, server-originated actions are notifications
		return this.notification_methods;
	}

	get from_either_methods(): Array<string> {
		// No actions are from_either in the new system
		return [];
	}

	// Utility to get imports needed by generators
	get_schema_imports(): Array<string> {
		return this.specs.map((spec) => to_action_spec_identifier(spec.method));
	}
}
