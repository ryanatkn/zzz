import type {
	Action_Spec,
	Client_Local_Action_Spec,
	Server_Notification_Action_Spec,
	Request_Response_Action_Spec,
} from '$lib/action_spec.js';
import type {Action_Method} from '$lib/action_metatypes.js';

/**
 * Convert an action name to its type name.
 */
export const to_action_spec_identifier = (method: Action_Method): string => `${method}_action_spec`;

/**
 * Convert an action name to its params type name.
 */
export const to_action_spec_params_identifier = (method: Action_Method): string =>
	`${to_action_spec_identifier(method)}.params`;

/**
 * Convert an action name to its response schema identifier.
 */
export const to_action_spec_response_params_identifier = (method: Action_Method): string =>
	`${to_action_spec_identifier(method)}.response_params`;

export const is_request_response_action = (
	spec: Action_Spec,
): spec is Request_Response_Action_Spec => spec.kind === 'request_response';

export const is_server_notification_action = (
	spec: Action_Spec,
): spec is Server_Notification_Action_Spec => spec.kind === 'server_notification';

export const is_client_local_action = (spec: Action_Spec): spec is Client_Local_Action_Spec =>
	spec.kind === 'client_local';

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
