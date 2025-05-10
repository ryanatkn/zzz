import {
	action_spec_by_method,
	type Action_From_Client,
	type Action_From_Server,
} from '$lib/action_collections.js';
import type {Action_Json} from '$lib/action_types.js';

// Constants for preview length and formatting
export const ACTION_DATE_FORMAT = 'MMM d, p';
export const ACTION_TIME_FORMAT = 'p';

// Helper function to convert an action to its json representation
export const create_action_json = (
	action: Action_From_Client | Action_From_Server,
): Action_Json | null => {
	const spec = action_spec_by_method.get(action.method);
	if (!spec) {
		console.error(`No action spec found for method: ${action.method}`, action);
		return null;
	}
	return {
		...action,
		kind: spec.kind,
		updated: action.created,
	};
};
