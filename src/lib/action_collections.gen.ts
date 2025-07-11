// @slop Claude Opus 4

import type {Gen} from '@ryanatkn/gro/gen.js';

import * as action_specs from '$lib/action_specs.js';
import {is_action_spec} from '$lib/action_spec.js';
import {Action_Registry} from '$lib/action_registry.js';
import {
	to_action_spec_input_identifier,
	to_action_spec_output_identifier,
} from '$lib/action_helpers.js';
import {Import_Builder, create_banner} from '$lib/codegen.js';

/**
 * Outputs a file with action collection types that can be imported by schemas.ts.
 * This is separate from `action_metatypes.gen.ts` to avoid circular dependencies.
 */
export const gen: Gen = ({origin_path}) => {
	const registry = new Action_Registry(
		Object.values(action_specs).filter((s) => is_action_spec(s)),
	);
	const imports = new Import_Builder();
	const banner = create_banner(origin_path);

	// Add base imports
	imports.add('zod', 'z');
	imports.add_type('$lib/action_spec.js', 'Action_Spec_Union');
	imports.add_many('$lib/action_specs.js', '* as specs');

	// Determine which data type to use for each method based on its spec
	const action_event_data_mappings = registry.specs.map((spec) => {
		const data_type =
			spec.kind === 'request_response'
				? 'Action_Event_Request_Response_Data'
				: spec.kind === 'remote_notification'
					? 'Action_Event_Remote_Notification_Data'
					: 'Action_Event_Local_Call_Data';

		imports.add_types('$lib/action_event_data.js', data_type);

		return `${spec.method}: ${data_type}<'${spec.method}'>`;
	});

	return `
		// ${banner}

		${imports.build()}

		// TODO consistent naming, maybe \`Action_Method_Union\`
		/**
		 * All method types combined.
		 */
		export const Action_Methods = z.enum([
			${registry.methods.map((method) => `'${method}'`).join(',\n\t\t\t')}
		]);
		export type Action_Methods = z.infer<typeof Action_Methods>;
		
		/**
		 * Action specifications indexed by method name.
		 * These represent the complete action spec definitions.
		 */
		export const Action_Specs = {
			${registry.specs
				.map((spec) => `${spec.method}: specs.${spec.method}_action_spec`)
				.join(',\n\t\t\t')}
		} as const;
		export interface Action_Specs {
			${registry.specs
				.map((spec) => `${spec.method}: typeof specs.${spec.method}_action_spec`)
				.join(';\n\t\t\t')}
		}

		export const action_specs: Array<Action_Spec_Union> = Object.values(Action_Specs);

		/**
		 * Action parameter schemas indexed by method name.
		 * These represent the input data for each action,
		 * e.g. JSON-RPC request/notification params and local call arguments.
		 */
		export const Action_Inputs = {
			${registry.specs
				.map((spec) => `${spec.method}: specs.${to_action_spec_input_identifier(spec.method)}`)
				.join(',\n\t\t\t')}
		} as const;
		export interface Action_Inputs {
			${registry.specs
				.map(
					(spec) =>
						`${spec.method}: z.infer<typeof specs.${to_action_spec_input_identifier(spec.method)}>`,
				)
				.join(';\n\t\t\t')}
		}

		/**
		 * Action result schemas indexed by method name.
		 * These represent the output data for each action,
		 * e.g. JSON-RPC response results and local call return values.
		 */
		export const Action_Outputs = {
			${registry.specs
				.map((spec) => `${spec.method}: specs.${to_action_spec_output_identifier(spec.method)}`)
				.join(',\n\t\t\t')}
		} as const;
		export interface Action_Outputs {
			${registry.specs
				.map(
					(spec) =>
						`${spec.method}: z.infer<typeof specs.${to_action_spec_output_identifier(spec.method)}>`,
				)
				.join(';\n\t\t\t')}
		}

		/**
		 * Action event data types indexed by method name.
		 * These represent the full discriminated union of all possible states
		 * for each action's event data, properly typed with inputs and outputs.
		 */
		export interface Action_Event_Datas {
			${action_event_data_mappings.join(';\n\t\t\t')}
		}

		// ${banner}
	`;
};
