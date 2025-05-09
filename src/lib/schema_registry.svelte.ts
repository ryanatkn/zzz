import {z} from 'zod';
import type {Flavored} from '@ryanatkn/belt/types.js';
import {SvelteMap} from 'svelte/reactivity';

import type {Action_Method} from '$lib/action_types.js';
import type {Action_Spec, Client_Action_Spec, Service_Action_Spec} from '$lib/schemas.js';

// TODO BLOCK refactor and use

export type Schema_Name = Flavored<string, 'Schema_Name'>;
export type Schema_Group = 'action' | 'model' | 'request' | 'response' | 'other';

/**
 * Schema registry for managing Zod schemas and action specifications.
 * This provides a centralized registry that can be used both on the client and server.
 */
export class Schema_Registry {
	/**
	 * Map of schema names to their Zod schemas.
	 */
	readonly #schemas: SvelteMap<Schema_Name, z.ZodTypeAny> = new SvelteMap();

	/**
	 * Map of schemas to their names, for reverse lookup.
	 */
	readonly #names: SvelteMap<z.ZodTypeAny, Schema_Name> = new SvelteMap();

	/**
	 * Groups schemas by category.
	 */
	readonly #schema_groups: SvelteMap<Schema_Group, Set<Schema_Name>> = new SvelteMap();

	/**
	 * Register a schema with the registry.
	 */
	register<T extends z.ZodTypeAny>(
		name: Schema_Name,
		schema: T,
		group: Schema_Group = 'other',
	): void {
		// Add to main registry
		this.#schemas.set(name, schema);
		this.#names.set(schema, name);

		// Add to group tracking
		let group_set = this.#schema_groups.get(group);
		if (!group_set) {
			group_set = new Set();
			this.#schema_groups.set(group, group_set);
		}
		group_set.add(name);
	}

	/**
	 * Get a schema by name.
	 */
	get<T extends z.ZodTypeAny>(name: Schema_Name): T {
		const schema = this.#schemas.get(name);
		if (!schema) {
			throw new Error(`Schema not found: ${name}`);
		}
		return schema as T;
	}

	/**
	 * Get the name of a schema.
	 * @throws if the schema is not found in the registry
	 */
	get_name(schema: z.ZodTypeAny): Schema_Name {
		const name = this.#names.get(schema);
		if (!name) {
			throw new Error('Schema not found in registry');
		}
		return name;
	}

	/**
	 * Get all schemas in a specific group.
	 */
	get_by_group(group: Schema_Group): Array<[Schema_Name, z.ZodTypeAny]> {
		const group_set = this.#schema_groups.get(group) || new Set();
		return Array.from(group_set).map((name) => [name, this.#schemas.get(name)!]);
	}

	/**
	 * Check if the registry contains a schema.
	 */
	has(name: Schema_Name): boolean {
		return this.#schemas.has(name);
	}

	/**
	 * Get all schema names.
	 */
	get names(): Array<Schema_Name> {
		return Array.from(this.#schemas.keys());
	}

	/**
	 * Get all schemas.
	 */
	get all(): Array<[Schema_Name, z.ZodTypeAny]> {
		return Array.from(this.#schemas.entries());
	}
}

/**
 * Registry for action specifications.
 */
export class Action_Registry {
	/**
	 * Map of action names to specifications.
	 */
	readonly #action_specs: Map<Action_Method, Action_Spec> = new SvelteMap();

	/**
	 * Set of client action names.
	 */
	readonly #client_actions: Set<Action_Method> = new Set();

	/**
	 * Set of server action names.
	 */
	readonly #server_actions: Set<Action_Method> = new Set();

	/**
	 * Register a client action specification.
	 */
	register_client_action(spec: Client_Action_Spec): void {
		this.#action_specs.set(spec.method, spec);
		this.#client_actions.add(spec.method);
	}

	/**
	 * Register a server action specification.
	 */
	register_server_action(spec: Service_Action_Spec): void {
		this.#action_specs.set(spec.method, spec);
		this.#server_actions.add(spec.method);
	}

	/**
	 * Get an action specification by name.
	 */
	get_spec(name: Action_Method): Action_Spec | undefined {
		return this.#action_specs.get(name);
	}

	/**
	 * Check if an action is a client action.
	 */
	is_client_action(name: Action_Method): boolean {
		return this.#client_actions.has(name);
	}

	/**
	 * Check if an action is a server action.
	 */
	is_server_action(name: Action_Method): boolean {
		return this.#server_actions.has(name);
	}

	/**
	 * Get the direction of an action ('client', 'server', or 'both').
	 */
	get_action_direction(name: Action_Method): 'client' | 'server' | 'both' {
		const is_client = this.is_client_action(name);
		const is_server = this.is_server_action(name);

		if (is_client && is_server) {
			return 'both';
		} else if (is_client) {
			return 'client';
		} else if (is_server) {
			return 'server';
		}

		throw new Error(`Unknown action: ${name}`);
	}

	/**
	 * Get all action specifications.
	 */
	get specs(): Array<Action_Spec> {
		return Array.from(this.#action_specs.values());
	}

	/**
	 * Get all client action names.
	 */
	get client_methods(): Array<Action_Method> {
		return Array.from(this.#client_actions);
	}

	/**
	 * Get all server action names.
	 */
	get server_methods(): Array<Action_Method> {
		return Array.from(this.#server_actions);
	}

	/**
	 * Get all client action specs.
	 */
	get client_specs(): Array<Client_Action_Spec> {
		return this.client_methods
			.map((name) => this.#action_specs.get(name))
			.filter(
				(spec): spec is Client_Action_Spec => spec !== undefined && spec.type === 'Client_Action',
			);
	}

	/**
	 * Get all server action specs.
	 */
	get server_specs(): Array<Service_Action_Spec> {
		return this.server_methods
			.map((name) => this.#action_specs.get(name))
			.filter(
				(spec): spec is Service_Action_Spec => spec !== undefined && spec.type === 'Service_Action',
			);
	}
}

/**
 * Combined registry that manages both schemas and actions.
 * This is the main entry point for schema and action registration and lookup.
 */
export class Zzz_Registry {
	readonly schemas = new Schema_Registry();
	readonly actions = new Action_Registry();

	/**
	 * Initialize the registry with schemas and action specs.
	 */
	init(schemas: Record<string, any>, action_specs: Array<Action_Spec>): void {
		// Register schemas
		for (const [name, schema] of Object.entries(schemas)) {
			if (schema instanceof z.ZodType) {
				let group: Schema_Group = 'other';

				if (name.endsWith('_Params')) {
					group = 'request';
				} else if (name.endsWith('_Response')) {
					group = 'response';
				} else if (name.startsWith('Action_')) {
					group = 'action';
				} else {
					group = 'model';
				}

				this.schemas.register(name as Schema_Name, schema, group);
			}
		}

		// Register action specs.
		for (const spec of action_specs) {
			if (spec.type === 'Client_Action') {
				this.actions.register_client_action(spec);
			} else {
				this.actions.register_server_action(spec);
			}
		}
	}
}
