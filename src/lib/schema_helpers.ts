import type {Action_Spec, Client_Action_Spec, Service_Action_Spec} from '$lib/action_spec.js';
import type {Action_Method} from '$lib/action_types.js';

/**
 * Convert an action name to its type name.
 */
export const to_action_spec_identifier = (method: Action_Method): string => `${method}_action_spec`;

/**
 * Convert an action name to its response schema identifier.
 */
export const to_action_message_identifier = (method: Action_Method): string =>
	`${method}_action_message`;

/**
 * Convert an action name to its params type name.
 */
export const to_action_spec_params_identifier = (method: Action_Method): string =>
	`${to_action_spec_identifier(method)}.params`;

/**
 * Convert an action name to its response schema identifier.
 */
export const to_action_spec_response_identifier = (method: Action_Method): string =>
	`${to_action_spec_identifier(method)}.response`;

/**
 * Check if the spec is for a service action.
 */
export const is_service_action = (spec: Action_Spec): spec is Service_Action_Spec =>
	spec.type === 'Service_Action';

/**
 * Check if the spec is for a client action.
 */
export const is_client_action = (spec: Action_Spec): spec is Client_Action_Spec =>
	spec.type === 'Client_Action';

/**
 * Convert a string from camelCase to snake_case.
 */
export const camel_to_snake_case = (str: string): string => {
	return str
		.replace(/([a-z0-9])([A-Z])/g, '$1_$2') // Replace camelCase boundaries with underscores
		.toLowerCase();
};

/**
 * Convert each segment of a snake_case identifier to Pascalsnake case,
 * e.g., "create_directory" -> "Create_Directory".
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
