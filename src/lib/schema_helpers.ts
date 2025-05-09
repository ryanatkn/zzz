import {type Action_Spec, type Client_Action_Spec, type Service_Action_Spec} from '$lib/schemas.js';

/**
 * Convert an action name to its params type name
 * @param action_name The name of the action
 * @returns The name of the action's params type
 */
export const to_action_params_name = (action_name: string): string =>
	`${to_pascalsnake_case(action_name)}_Action_Params`;

/**
 * Convert an action name to its response type name
 * @param action_name The name of the action
 * @returns The name of the action's response type
 */
export const to_action_response_name = (action_name: string): string =>
	`${to_pascalsnake_case(action_name)}_Action_Response`;

/**
 * Check if the schema is for a service action
 * @param schema The action specification
 * @returns True if the schema is for a service action
 */
export const is_service_action = (schema: Action_Spec): schema is Service_Action_Spec =>
	schema.type === 'Service_Action';

/**
 * Check if the schema is for a client action
 * @param schema The action specification
 * @returns True if the schema is for a client action
 */
export const is_client_action = (schema: Action_Spec): schema is Client_Action_Spec =>
	schema.type === 'Client_Action';

/**
 * Convert a string from camelCase to snake_case
 * @param str String to convert
 * @returns The snake_case string
 */
export const camel_to_snake_case = (str: string): string => {
	return str
		.replace(/([a-z0-9])([A-Z])/g, '$1_$2') // Replace camelCase boundaries with underscores
		.toLowerCase();
};

/**
 * Convert a string to snake_case, handling various input formats
 * @param str String to convert
 * @param from_camel If true, assume input is camelCase
 * @returns The snake_case string
 */
export const to_snake_case = (str: string, from_camel = true): string => {
	if (from_camel) {
		return camel_to_snake_case(str);
	}
	// Otherwise assume it's already snake case or similar format
	return str.toLowerCase();
};

/**
 * Convert a string to UPPER_SNAKE_CASE
 * @param str String to convert
 * @param from_camel If true, assume input is camelCase
 * @returns The UPPER_SNAKE_CASE string
 */
export const to_uppersnake_case = (str: string, from_camel = true): string => {
	if (from_camel) {
		return str
			.replace(/([a-z0-9])([A-Z])/g, '$1_$2') // Replace camelCase boundaries with underscores
			.toUpperCase();
	}
	return str.toUpperCase();
};

/**
 * Convert each segment of a snake_case identifier to Pascal case
 * e.g., "create_directory" -> "Create_Directory"
 * @param str String to convert
 * @param from_camel If true, convert from camelCase first
 * @returns The Pascal_Snake_Case string
 */
export const to_pascalsnake_case = (str: string, from_camel = false): string => {
	let result = str;
	if (from_camel) {
		result = camel_to_snake_case(str);
	}
	return result
		.split('_')
		.map((s) => s.charAt(0).toUpperCase() + s.slice(1))
		.join('_');
};

/**
 * Get import list for schemas based on action specifications
 * @param schemas Array of action specifications
 * @returns Array of schema names that need to be imported
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
