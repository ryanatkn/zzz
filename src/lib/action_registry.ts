import {DEV} from 'esm-env';

import type {Action_Spec, Service_Action_Spec, Client_Action_Spec} from '$lib/action_spec.js';
import {Action_Method} from '$lib/action_metatypes.js';
import {to_action_spec_identifier} from '$lib/schema_helpers.js';

/**
 * Lightweight nonreactive class that may be deleted or changed to be reactive.
 * Inefficiently recalculates with getters.
 */
export class Action_Registry {
	/**
	 * Map of action methods to their specifications.
	 */
	readonly #specs: Map<string, Action_Spec> = new Map();

	/**
	 * Map of client action methods to their specifications.
	 */
	readonly #client_specs: Map<string, Client_Action_Spec> = new Map();

	/**
	 * Map of service action methods to their specifications.
	 */
	readonly #service_specs: Map<string, Service_Action_Spec> = new Map();

	constructor(action_specs?: Array<Action_Spec>) {
		if (action_specs) {
			this.register_many(action_specs);
		}
	}

	/**
	 * Register an action specification with the registry.
	 */
	register(spec: Action_Spec): void {
		this.#specs.set(spec.method, spec);

		if (spec.type === 'Client_Action') {
			this.#client_specs.set(spec.method, spec);
		} else {
			this.#service_specs.set(spec.method, spec);
		}

		if (DEV) {
			// Validate that method matches enum
			try {
				Action_Method.parse(spec.method);
			} catch (error) {
				console.error(
					`Error registering action '${spec.method}': not found in Action_Method enum`,
					error,
				);
				throw error;
			}
		}
	}

	/**
	 * Register multiple action specifications at once.
	 */
	register_many(specs: Array<Action_Spec>): void {
		for (const spec of specs) {
			this.register(spec);
		}
	}

	/**
	 * Get an action specification by method name.
	 */
	get_spec(method: string): Action_Spec | undefined {
		return this.#specs.get(method);
	}

	/**
	 * Get all registered action specifications.
	 */
	get specs(): Array<Action_Spec> {
		return Array.from(this.#specs.values());
	}

	/**
	 * Get all client-only action specifications.
	 */
	get client_specs(): Array<Client_Action_Spec> {
		return Array.from(this.#client_specs.values());
	}

	/**
	 * Get all service action specifications.
	 */
	get service_specs(): Array<Service_Action_Spec> {
		return Array.from(this.#service_specs.values());
	}

	/**
	 * Get all client action method names.
	 */
	get client_methods(): Array<string> {
		return Array.from(this.#client_specs.keys());
	}

	/**
	 * Get all service action method names.
	 */
	get service_methods(): Array<string> {
		return Array.from(this.#service_specs.keys());
	}

	/**
	 * Get all networked service action specifications (those with non-null http_method).
	 */
	get networked_specs(): Array<Service_Action_Spec> {
		return this.service_specs.filter((spec) => spec.http_method !== null);
	}

	/**
	 * Get all non-networked service action specifications (those with null http_method).
	 */
	get nonnetworked_specs(): Array<Service_Action_Spec> {
		return this.service_specs.filter((spec) => spec.http_method === null);
	}

	/**
	 * Get all networked service action method names.
	 */
	get networked_methods(): Array<string> {
		return this.networked_specs.map((spec) => spec.method);
	}

	/**
	 * Get all non-networked service action method names.
	 */
	get nonnetworked_methods(): Array<string> {
		return this.nonnetworked_specs.map((spec) => spec.method);
	}

	/**
	 * Get all action specifications with "from_client" direction.
	 */
	get from_client_specs(): Array<Action_Spec> {
		return this.specs.filter((spec) => spec.direction === 'from_client');
	}

	/**
	 * Get all action specifications with "from_server" direction.
	 */
	get from_server_specs(): Array<Action_Spec> {
		return this.specs.filter((spec) => spec.direction === 'from_server');
	}

	/**
	 * Get all action specifications with "from_either" direction.
	 */
	get from_either_specs(): Array<Action_Spec> {
		return this.specs.filter((spec) => spec.direction === 'from_either');
	}

	/**
	 * Get all action method names with "from_client" direction.
	 */
	get from_client_methods(): Array<string> {
		return this.from_client_specs.map((spec) => spec.method);
	}

	/**
	 * Get all action method names with "from_server" direction.
	 */
	get from_server_methods(): Array<string> {
		return this.from_server_specs.map((spec) => spec.method);
	}

	/**
	 * Get all action method names with "from_either" direction.
	 */
	get from_either_methods(): Array<string> {
		return this.from_either_specs.map((spec) => spec.method);
	}

	/**
	 * Check if an action is a client action.
	 */
	is_client_action(method: string): boolean {
		return this.#client_specs.has(method);
	}

	/**
	 * Check if an action is a service action.
	 */
	is_service_action(method: string): boolean {
		return this.#service_specs.has(method);
	}

	/**
	 * Get schema imports needed for all registered actions.
	 */
	get_schema_imports(): Array<string> {
		const imports: Set<string> = new Set();

		for (const spec of this.specs) {
			imports.add(to_action_spec_identifier(spec.method));
		}

		return Array.from(imports).sort();
	}
}
