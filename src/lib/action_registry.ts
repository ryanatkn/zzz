import {DEV} from 'esm-env';
import {SvelteMap} from 'svelte/reactivity';

import type {Action_Spec, Service_Action_Spec, Client_Action_Spec} from '$lib/action_spec.js';
import {Action_Method} from '$lib/action_types.js';
import {to_action_response_name, to_action_spec_identifier} from '$lib/schema_helpers.js';

/**
 * Registry for action specifications that serves as the single source of truth.
 * This provides a centralized registry that can be used both on the client and server.
 */
export class Action_Registry {
	/**
	 * Map of action methods to their specifications.
	 */
	readonly #specs: SvelteMap<string, Action_Spec> = new SvelteMap();

	/**
	 * Map of client action methods to their specifications.
	 */
	readonly #client_specs: SvelteMap<string, Client_Action_Spec> = new SvelteMap();

	/**
	 * Map of service action methods to their specifications.
	 */
	readonly #service_specs: SvelteMap<string, Service_Action_Spec> = new SvelteMap();

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
	 * Get the direction of an action ('client', 'server', or 'both').
	 */
	get_direction(method: string): 'client' | 'server' | 'both' {
		const is_client = this.#client_specs.has(method);
		const is_server = this.#service_specs.has(method);

		if (is_client && is_server) {
			return 'both';
		} else if (is_client) {
			return 'client';
		} else if (is_server) {
			return 'server';
		}

		throw new Error(`Unknown action method: ${method}`);
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
