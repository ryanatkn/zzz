import {action_specs} from '$lib/schema_metadata.js';
import {Action_Registry} from '$lib/action_registry.js';

/**
 * Create and populate a registry with all defined actions.
 */
export const create_action_registry = (): Action_Registry => {
	const registry = new Action_Registry();
	registry.register_many(action_specs);
	return registry;
};

/**
 * Global singleton registry for convenience in imports.
 * For code that has access to Zzz or Zzz_Server instances, prefer using
 * their .action_registry property instead.
 */
export const global_action_registry = create_action_registry();
