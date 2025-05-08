/**
 * Converts an action name to its params type name
 * Example: "Action_Ping" -> "Action_Ping_Params"
 */
export const to_action_params_name = (name: string): string =>
	capitalize_identifier(name) + '_Params';

/**
 * Converts an action name to its response type name
 * Example: "Action_Ping" -> "Action_Ping_Response"
 */
export const to_action_response_name = (name: string): string =>
	capitalize_identifier(name) + '_Response';

// TODO extract
// only supports identifers separated with underscores, but could be expanded to included camelCase
const capitalize_identifier = (identifier: string): string =>
	identifier
		.split('_')
		.map((s) => s[0].toUpperCase() + s.substring(1))
		.join('_');
