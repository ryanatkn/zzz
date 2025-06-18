// @slop claude_opus_4
// action_registry.ts

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

	get backend_specs(): Array<Action_Spec> {
		return this.specs.filter((spec) => spec.kind !== 'local_call');
	}

	get frontend_specs(): Array<Action_Spec> {
		return this.specs;
	}

	get backend_to_frontend_specs(): Array<Action_Spec> {
		return this.specs.filter((spec) => spec.initiator === 'backend' || spec.initiator === 'both');
	}

	get frontend_to_backend_specs(): Array<Action_Spec> {
		return this.specs.filter((spec) => spec.initiator === 'frontend' || spec.initiator === 'both');
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

	get backend_methods(): Array<Action_Method> {
		return this.backend_specs.map((spec) => spec.method);
	}

	get frontend_methods(): Array<Action_Method> {
		return this.frontend_specs.map((spec) => spec.method);
	}

	get frontend_to_backend_methods(): Array<Action_Method> {
		return this.frontend_to_backend_specs.map((spec) => spec.method);
	}

	get backend_to_frontend_methods(): Array<Action_Method> {
		return this.backend_to_frontend_specs.map((spec) => spec.method);
	}

	get_schema_imports(): Array<string> {
		return this.specs.map((spec) => to_action_spec_identifier(spec.method));
	}
}
