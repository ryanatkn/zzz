import type {Action_Auth} from '$lib/action_types.js';
import {Action_Method} from '$lib/action_metatypes.js';

export const ACTION_DATE_FORMAT = 'MMM d, p';
export const ACTION_TIME_FORMAT = 'p';

// TODO @api rethink these
/**
 * Convert an action name to its type name.
 */
export const to_action_spec_identifier = (method: Action_Method): string => `${method}_action_spec`;

/**
 * Convert an action name to its params type name.
 */
export const to_action_spec_input_identifier = (method: Action_Method): string =>
	`${to_action_spec_identifier(method)}.input`;

/**
 * Convert an action name to its response schema identifier.
 */
export const to_action_spec_output_identifier = (method: Action_Method): string =>
	`${to_action_spec_identifier(method)}.output`;

export const to_action_spec_auth_identifier = (auth: Action_Auth): string =>
	auth === 'public' ? 'Public_Backend_Action_Handler' : 'Authorized_Backend_Action_Handler';
