// @slop claude_opus_4

import type {z} from 'zod';
import type {Flavored} from '@ryanatkn/belt/types.js';
import {Unreachable_Error} from '@ryanatkn/belt/error.js';

import type {
	Action_Spec,
	Request_Response_Action_Spec,
	Remote_Notification_Action_Spec,
	Local_Call_Action_Spec,
} from '$lib/action_spec.js';
import type {Action_Method} from '$lib/action_metatypes.js';

// TODO currently unused

export type Vocab_Name = Flavored<string, 'Vocab_Name'>;

/**
 * A central registry for schemas and actions.
 * Provides a single source of truth for schema definitions.
 */
export class Schema_Registry {
	/**
	 * All schemas, including model schemas, action params, and responses.
	 */
	schemas: Array<z.ZodTypeAny> = [];

	/**
	 * Model schemas are distinct from the action schemas.
	 * Models are the nouns compared to the Action verbs,
	 * and compared to Views they are data not Svelte components.
	 */
	model_schemas: Array<z.ZodTypeAny> = [];

	/**
	 * Action parameter schemas.
	 */
	action_params_schemas: Array<z.ZodTypeAny> = [];

	/**
	 * Action response schemas.
	 */
	action_response_schemas: Array<z.ZodTypeAny> = [];

	/**
	 * Map of schema names to schemas.
	 */
	schema_by_name: Map<Vocab_Name, z.ZodTypeAny> = new Map();

	/**
	 * Map of schemas to their names, for reverse lookup.
	 * Zod schemas don't have a `name` property and we don't want to abuse `description`.
	 */
	name_by_schema: Map<z.ZodTypeAny, Vocab_Name> = new Map();

	/**
	 * Collection of all action specs.
	 */
	action_specs: Array<Action_Spec> = [];

	/**
	 * Collection of 'request_response' action specs.
	 */
	request_response_action_specs: Array<Request_Response_Action_Spec> = [];

	/**
	 * Collection of 'remote_notification' action specs.
	 */
	remote_notification_action_specs: Array<Remote_Notification_Action_Spec> = [];

	/**
	 * Collection of 'local_call' action specs.
	 */
	local_call_action_specs: Array<Local_Call_Action_Spec> = [];

	/**
	 * Map of action spec names to action specs.
	 */
	action_spec_by_name_map: Map<Action_Method, Action_Spec> = new Map();

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
			this.action_specs.push(schema);
			this.action_spec_by_name_map.set(schema.method, schema);

			switch (schema.kind) {
				case 'request_response':
					this.request_response_action_specs.push(schema);
					break;
				case 'remote_notification':
					this.remote_notification_action_specs.push(schema);
					break;
				case 'local_call':
					this.local_call_action_specs.push(schema);
					break;
				default:
					throw new Unreachable_Error(schema);
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
}

/**
 * Global instance of the schema registry for convenience.
 */
export const global_schema_registry = new Schema_Registry();
