import {type Action_Spec, type Client_Action_Spec, type Service_Action_Spec} from '$lib/schemas.js';

export const to_action_params_name = (action_name: string): string => `${action_name}_Params`;

export const to_action_response_name = (action_name: string): string => `${action_name}_Response`;

/**
 * Converts an action name to a lowercase API path fragment.
 * Example: "Action_Ping" -> "ping"
 * Handles both "Action_Name" and just "Name" formats
 */
export const to_api_path = (action_name: string): string => {
	const stripped = action_name.startsWith('Action_') ? action_name.substring(7) : action_name;
	return stripped.toLowerCase();
};

/**
 * Extracts the base action name from a params or response type name
 * Example: "Action_Ping_Params" -> "Action_Ping"
 */
export const extract_action_name = (type_name: string): string => {
	if (type_name.endsWith('_Params')) {
		return type_name.slice(0, -7);
	}
	if (type_name.endsWith('_Response')) {
		return type_name.slice(0, -9);
	}
	return type_name;
};

/**
 * Checks if a string is a valid action params type name
 */
export const is_action_params_name = (name: string): boolean => name.endsWith('_Params');

/**
 * Checks if a string is a valid action response type name
 */
export const is_action_response_name = (name: string): boolean => name.endsWith('_Response');

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
 * Transform parameter name to a consistent format
 */
export const format_param_name = (name: string): string => {
	// Strip 'Action_' prefix if present
	const stripped = name.startsWith('Action_') ? name.substring(7) : name;
	// Convert to snake_case if not already
	return to_snake_case(stripped);
};

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
