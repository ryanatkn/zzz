import {get_datetime_now} from '$lib/zod_helpers.js';
import type {Action_From_Client, Action_From_Server} from '$lib/action_collections.js';
import {Action_Direction} from '$lib/action_spec.js';
import type {Action_Json} from '$lib/action_types.js';

// Constants for preview length and formatting
export const ACTION_DATE_FORMAT = 'MMM d, p';
export const ACTION_TIME_FORMAT = 'p';

// TODO BLOCK hack, maybe replace with the actions proxy - lookup message
// Helper function to convert an action to its json representation
export const create_action_json = (
	action: Action_From_Client | Action_From_Server,
	direction: Action_Direction,
): Action_Json => {
	return {
		...action,
		updated: action.created,
		direction,
		created: get_datetime_now(),
	} as Action_Json;
};
