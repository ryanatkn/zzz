import {type Action_Spec, type Client_Action_Spec, type Service_Action_Spec} from '$lib/schemas.js';

export const to_action_params_name = (action_name: string): string => `${action_name}_Params`;

export const to_action_response_name = (action_name: string): string => `${action_name}_Response`;

/**
 * Check if the schema is for a service action
 */
export const is_service_action = (schema: Action_Spec): schema is Service_Action_Spec =>
	schema.type === 'Service_Action';

/**
 * Check if the schema is for a client action
 */
export const is_client_action = (schema: Action_Spec): schema is Client_Action_Spec =>
	schema.type === 'Client_Action';

/**
 * Convert a string to snake_case
 */
export const to_snake_case = (str: string): string => {
	return str
		.replace(/([a-z])([A-Z])/g, '$1_$2') // Replace camelCase boundaries with underscores
		.toLowerCase();
};

/**
 * Get import list for schemas
 */
export const get_schema_imports = (schemas: Array<Action_Spec>): Array<string> => {
	const types: Set<string> = new Set();

	for (const schema of schemas) {
		// Add param and response type names
		types.add(to_action_params_name(schema.name));
		if (is_service_action(schema)) {
			types.add(to_action_response_name(schema.name));
		}
	}

	return Array.from(types).sort();
};
