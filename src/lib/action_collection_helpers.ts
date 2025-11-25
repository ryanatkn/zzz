import type {z} from 'zod';

import {ActionInputs, ActionOutputs} from './action_collections.js';

/**
 * Parse action params with validation.
 */
export const parse_action_input = <TMethod extends keyof typeof ActionInputs>(
	method: TMethod,
	data: unknown,
): ActionInputs[TMethod] => ActionInputs[method].parse(data) as ActionInputs[TMethod];

/**
 * Parse action result with validation.
 */
export const parse_action_output = <TMethod extends keyof typeof ActionOutputs>(
	method: TMethod,
	data: unknown,
): ActionOutputs[TMethod] => ActionOutputs[method].parse(data) as ActionOutputs[TMethod];

/**
 * Safe parse action params.
 */
export const safe_parse_action_input = <TMethod extends keyof typeof ActionInputs>(
	method: TMethod,
	data: unknown,
): z.ZodSafeParseResult<ActionInputs[TMethod]> =>
	ActionInputs[method].safeParse(data) as z.ZodSafeParseResult<ActionInputs[TMethod]>;

/**
 * Safe parse action result.
 */
export const safe_parse_action_output = <TMethod extends keyof typeof ActionOutputs>(
	method: TMethod,
	data: unknown,
): z.ZodSafeParseResult<ActionOutputs[TMethod]> =>
	ActionOutputs[method].safeParse(data) as z.ZodSafeParseResult<ActionOutputs[TMethod]>;
