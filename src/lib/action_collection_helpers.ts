import type {z} from 'zod';

import {Action_Inputs, Action_Outputs} from '$lib/action_collections.js';

/**
 * Parse action params with validation.
 */
export const parse_action_input = <T_Method extends keyof typeof Action_Inputs>(
	method: T_Method,
	data: unknown,
): Action_Inputs[T_Method] => Action_Inputs[method].parse(data) as Action_Inputs[T_Method];

/**
 * Parse action result with validation.
 */
export const parse_action_output = <T_Method extends keyof typeof Action_Outputs>(
	method: T_Method,
	data: unknown,
): Action_Outputs[T_Method] => Action_Outputs[method].parse(data) as Action_Outputs[T_Method];

/**
 * Safe parse action params.
 */
export const safe_parse_action_input = <T_Method extends keyof typeof Action_Inputs>(
	method: T_Method,
	data: unknown,
): z.SafeParseReturnType<unknown, Action_Inputs[T_Method]> =>
	Action_Inputs[method].safeParse(data) as z.SafeParseReturnType<unknown, Action_Inputs[T_Method]>;

/**
 * Safe parse action result.
 */
export const safe_parse_action_output = <T_Method extends keyof typeof Action_Outputs>(
	method: T_Method,
	data: unknown,
): z.SafeParseReturnType<unknown, Action_Outputs[T_Method]> =>
	Action_Outputs[method].safeParse(data) as z.SafeParseReturnType<
		unknown,
		Action_Outputs[T_Method]
	>;
