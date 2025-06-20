// @slop claude_opus_4

import type {Gen} from '@ryanatkn/gro/gen.js';

import {action_specs} from '$lib/action_collections.js';
import {Action_Registry} from '$lib/action_registry.js';
import {Import_Builder, generate_phase_handlers, create_banner} from '$lib/codegen.js';

/**
 * Generates frontend action handler types based on spec.initiator.
 * Frontend can handle:
 * - send/execute phases when initiator is 'frontend' or 'both'
 * - receive phases when initiator is 'backend' or 'both'
 *
 * Example generated imports:
 * ```typescript
 * import type {Action_Event} from '$lib/action_event.js';
 * import type {Action_Inputs, Action_Outputs} from '$lib/action_collections.js';
 * import type {Frontend} from '$lib/frontend.svelte.js';
 * ```
 */
export const gen: Gen = ({origin_path}) => {
	const registry = new Action_Registry(action_specs);
	const banner = create_banner(origin_path);
	const imports = new Import_Builder();

	// Generate handlers for each spec, building imports on demand
	const frontend_action_handlers = registry.specs
		.map((spec) => generate_phase_handlers(spec, 'frontend', imports))
		.filter(Boolean) // Remove empty strings
		.join(';\n\t');

	return `
		// ${banner}

		${imports.build()}

		/**
		 * Frontend action handlers organized by method and phase.
		 * Generated using spec.initiator to determine valid phases:
		 * - initiator: 'frontend' → send/execute phases
		 * - initiator: 'backend' → receive phases
		 * - initiator: 'both' → all valid phases
		 */
		export interface Frontend_Action_Handlers {
			${frontend_action_handlers}
		}

		// ${banner}
	`;
};
