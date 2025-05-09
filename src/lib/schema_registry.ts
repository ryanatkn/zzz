import type {z} from 'zod';
import type {Flavored} from '@ryanatkn/belt/types.js';

import type {Action_Spec, Client_Action_Spec, Service_Action_Spec} from '$lib/action_spec.js';
import type {Action_Method} from '$lib/action_types.js';

export type Vocab_Name = Flavored<string, 'Vocab_Name'>;

/**
 * A central registry for schemas and actions.
 * Provides a single source of truth for schema definitions.
 */
export class Schema_Registry {
	/**
	 * All schemas, including model schemas, action params, and responses.
	 */
	private schemas: Array<z.ZodTypeAny> = [];

	/**
	 * Model schemas are distinct from the action schemas.
	 * Models are the nouns compared to the Action verbs,
	 * and compared to Views they are data not Svelte components.
	 */
	private model_schemas: Array<z.ZodTypeAny> = [];

	/**
	 * Action parameter schemas.
	 */
	private action_params_schemas: Array<z.ZodTypeAny> = [];

	/**
	 * Action response schemas.
	 */
	private action_response_schemas: Array<z.ZodTypeAny> = [];

	/**
	 * Map of schema names to schemas.
	 */
	private schema_by_name: Map<Vocab_Name, z.ZodTypeAny> = new Map();

	/**
	 * Map of schemas to their names, for reverse lookup.
	 * Zod schemas don't have a `name` property and we don't want to abuse `description`.
	 */
	private name_by_schema: Map<z.ZodTypeAny, Vocab_Name> = new Map();

	/**
	 * Collection of all action specs.
	 */
	private action_specs_array: Array<Action_Spec> = [];

	/**
	 * Collection of client-only action specs.
	 */
	private client_action_specs_array: Array<Client_Action_Spec> = [];

	/**
	 * Collection of service action specs.
	 */
	private service_action_specs_array: Array<Service_Action_Spec> = [];

	/**
	 * Map of action spec names to action specs.
	 */
	private action_spec_by_name_map: Map<Action_Method, Action_Spec> = new Map();

	/**
	 * Add a schema to the appropriate registries.
	 */
	add_schema(name: Vocab_Name, schema: z.ZodTypeAny | Action_Spec): void {
		if ('_def' in schema) {
			// It's a Zod schema
			this.schemas.push(schema);
			this.schema_by_name.set(name, schema);
			this.name_by_schema.set(schema, name);

			if (name.endsWith('_Params')) {
				this.action_params_schemas.push(schema);
			} else if (name.endsWith('_Response')) {
				this.action_response_schemas.push(schema);
			} else {
				this.model_schemas.push(schema);
			}
		} else if ('type' in schema) {
			// It's an action spec
			this.action_specs_array.push(schema);
			this.action_spec_by_name_map.set(schema.method, schema);

			if (schema.type === 'Service_Action') {
				this.service_action_specs_array.push(schema);
			} else if (schema.type === 'Client_Action') {
				this.client_action_specs_array.push(schema);
			}
		}
	}

	/**
	 * Register multiple schemas at once.
	 */
	register_many(schemas: Record<string, any>): void {
		for (const name in schemas) {
			this.add_schema(name as Vocab_Name, schemas[name]);
		}
	}

	/**
	 * Lookup a schema name, guaranteed to return a string, or throws.
	 */
	lookup_schema_name(schema: z.ZodTypeAny): Vocab_Name {
		const name = this.name_by_schema.get(schema);
		if (!name) {
			throw new Error(`Schema not found in name_by_schema registry`);
		}
		return name;
	}

	/**
	 * Get an action specification by method name.
	 */
	get_action_spec(method: Action_Method): Action_Spec | undefined {
		return this.action_spec_by_name_map.get(method);
	}

	/**
	 * Get all registered action specifications.
	 */
	get action_specs(): Array<Action_Spec> {
		return [...this.action_specs_array];
	}

	/**
	 * Get all client-only action specifications.
	 */
	get client_action_specs(): Array<Client_Action_Spec> {
		return [...this.client_action_specs_array];
	}

	/**
	 * Get all service action specifications.
	 */
	get service_action_specs(): Array<Service_Action_Spec> {
		return [...this.service_action_specs_array];
	}

	/**
	 * Get all schema names.
	 */
	get schema_names(): Array<Vocab_Name> {
		return Array.from(this.schema_by_name.keys());
	}

	/**
	 * Get a schema by name.
	 */
	get_schema(name: Vocab_Name): z.ZodTypeAny | undefined {
		return this.schema_by_name.get(name);
	}

	/**
	 * Get all action parameter schemas.
	 */
	get params_schemas(): Array<z.ZodTypeAny> {
		return [...this.action_params_schemas];
	}

	/**
	 * Get all action response schemas.
	 */
	get response_schemas(): Array<z.ZodTypeAny> {
		return [...this.action_response_schemas];
	}
}

/**
 * Global instance of the schema registry for convenience.
 */
export const global_schema_registry = new Schema_Registry();
