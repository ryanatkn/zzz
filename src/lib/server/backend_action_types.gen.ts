// @slop claude_opus_4
// server/backend_action_types.gen.ts

import type {Gen} from '@ryanatkn/gro/gen.js';

import {action_specs} from '$lib/action_collections.js';
import {Action_Registry} from '$lib/action_registry.js';
import {Import_Builder, generate_phase_handlers, create_banner} from '$lib/codegen.js';

/**
 * Generates backend action handler types based on spec.initiator.
 * Backend can handle:
 * - send/execute phases when initiator is 'backend' or 'both'
 * - receive phases when initiator is 'frontend' or 'both'
 *
 * Example generated imports:
 * ```typescript
 * import type {Action_Event} from '$lib/action_event.js';
 * import type {Action_Outputs} from '$lib/action_collections.js';
 * import type {Backend} from '$lib/server/backend.js';
 * ```
 */
export const gen: Gen = ({origin_path}) => {
	const registry = new Action_Registry(action_specs);
	const banner = create_banner(origin_path);
	const imports = new Import_Builder();

	// Generate handlers for each spec, building imports on demand
	const backend_action_handlers = registry.specs
		.map((spec) => generate_phase_handlers(spec, 'backend', imports))
		.join(';\n\t');

	return `
		// ${banner}

		${imports.build()}

		/**
		 * Backend action handlers organized by method and phase.
		 * Generated using spec.initiator to determine valid phases:
		 * - initiator: 'backend' → send/execute phases
		 * - initiator: 'frontend' → receive phases
		 * - initiator: 'both' → all valid phases
		 */
		export interface Backend_Action_Handlers {
			${backend_action_handlers}
		}

		// ${banner}
	`;
};
