import type {z} from 'zod';
import type {Flavored} from '@ryanatkn/belt/types.js';
import {unreachable} from '@ryanatkn/belt/error.js';

import * as schemas from '$lib/schemas.js';
import type {Action_Schema_Name, Action_Schema} from '$lib/schemas.js';

export type Vocab_Name = Flavored<string, 'Vocab_Name'>;

/**
 * Model schemas are distinct from the action schemas.
 * Models are the nouns compared to the Action verbs,
 * and compared to Views they are data not Svelte components.
 */
export const model_schemas: Array<z.ZodTypeAny> = [];

/**
 * Collection of all action schemas
 */
export const action_schemas: Array<Action_Schema> = [];

/**
 * Collection of client-only action schemas
 */
export const client_action_schemas: Array<schemas.Client_Action_Schema> = [];

/**
 * Collection of service action schemas
 */
export const service_action_schemas: Array<schemas.Service_Action_Schema> = [];

/**
 * Map of action schema names to action schemas
 */
export const action_schema_by_name: Map<Action_Schema_Name, Action_Schema> = new Map();

/**
 * Collection of action parameter schemas
 */
export const action_params_schemas: Array<z.ZodTypeAny> = [];

/**
 * Collection of action response schemas
 */
export const action_response_schemas: Array<z.ZodTypeAny> = [];

/**
 * All schemas registry
 */
export const schemas_registry: Array<z.ZodTypeAny> = [];

/**
 * Map of schema names to schemas
 */
export const schema_by_name: Map<Vocab_Name, z.ZodTypeAny> = new Map();

/**
 * Map of schemas to their names, for reverse lookup
 * Zod schemas don't have a `name` property and we don't want to abuse `description`
 */
export const name_by_schema: Map<z.ZodTypeAny, Vocab_Name> = new Map();

/**
 * Lookup a schema name, guaranteed to return a string, or throws.
 */
export const lookup_schema_name = (schema: z.ZodTypeAny): string => {
	const name = name_by_schema.get(schema);
	if (!name) {
		throw new Error(`Schema not found in name_by_schema registry`);
	}
	return name;
};

/**
 * Add a schema to the appropriate registries.
 */
export const add_schema = (name: Vocab_Name, schema: Action_Schema | z.ZodTypeAny): void => {
	if ('_def' in schema) {
		schemas_registry.push(schema);
		schema_by_name.set(name, schema);
		name_by_schema.set(schema, name);
		if (name.endsWith('_Params')) {
			action_params_schemas.push(schema);
		} else if (name.endsWith('_Response')) {
			action_response_schemas.push(schema);
		} else {
			model_schemas.push(schema);
		}
	} else if ('type' in schema) {
		action_schemas.push(schema);
		action_schema_by_name.set(schema.name, schema);
		switch (schema.type) {
			case 'Service_Action':
				service_action_schemas.push(schema);
				break;
			case 'Client_Action':
				client_action_schemas.push(schema);
				break;
			default:
				unreachable(schema, `Unknown action type: ${(schema as any).type}`);
		}
	} // else some other value exported from the module, intentionally not encoded in the helper type
};

// Initialize the registry with all schemas from the action_schemas module
for (const name in schemas) {
	add_schema(name as Vocab_Name, (schemas as any)[name]);
}
