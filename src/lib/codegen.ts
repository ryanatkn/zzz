// @slop
// codegen.ts

import type {Action_Spec} from '$lib/action_spec.js';
import type {Action_Phase} from '$lib/action_types.js';

/**
 * Manages imports for generated code, building them on demand.
 */
export class Import_Builder {
	imports: Map<string, Set<string>> = new Map();

	/**
	 * Add an import to be included in the generated code.
	 * @param from The module to import from
	 * @param what What to import (can be a type or value)
	 */
	add(from: string, what: string): this {
		if (!this.imports.has(from)) {
			this.imports.set(from, new Set());
		}
		this.imports.get(from)!.add(what);
		return this;
	}

	/**
	 * Add a type import to be included in the generated code.
	 * This is a convenience method that prepends 'type' if not already present.
	 */
	add_type(from: string, what: string): this {
		const type_import = what.startsWith('type ') ? what : `type ${what}`;
		return this.add(from, type_import);
	}

	/**
	 * Generate the import statements.
	 */
	build(): string {
		const statements: Array<string> = [];

		for (const [from, imports] of this.imports) {
			const sorted_imports = Array.from(imports).sort();
			statements.push(`import {${sorted_imports.join(', ')}} from '${from}';`);
		}

		return statements.join('\n');
	}
}

/**
 * Determines which phases an executor can handle based on the action spec.
 */
export const get_executor_phases = (
	spec: Action_Spec,
	executor: 'frontend' | 'backend',
): Array<Action_Phase> => {
	const {kind, initiator} = spec;
	const phases: Array<Action_Phase> = [];

	if (kind === 'request_response') {
		// Executor can send/receive based on initiator
		const can_send = initiator === executor || initiator === 'both';
		const can_receive = initiator === 'both' || initiator !== executor;

		if (executor === 'frontend') {
			if (can_send) phases.push('send_request', 'receive_response');
			if (can_receive) phases.push('receive_request', 'send_response');
		} else {
			if (can_send) phases.push('send_request', 'receive_response');
			if (can_receive) phases.push('receive_request', 'send_response');
		}
	} else if (kind === 'remote_notification') {
		const can_send = initiator === executor || initiator === 'both';
		const can_receive = initiator === 'both' || initiator !== executor;

		if (can_send) phases.push('send');
		if (can_receive) phases.push('receive');
		// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
	} else if (kind === 'local_call') {
		const can_execute = initiator === executor || initiator === 'both';
		if (can_execute) phases.push('execute');
	}

	return phases;
};

/**
 * Gets the action event type name for a specific kind and executor.
 */
export const get_action_event_type = (
	kind: 'request_response' | 'remote_notification' | 'local_call',
	executor: 'frontend' | 'backend',
): string => {
	const prefix = executor === 'frontend' ? 'Frontend' : 'Backend';

	switch (kind) {
		case 'request_response':
			return `${prefix}_Request_Response_Action_Event`;
		case 'remote_notification':
			return `${prefix}_Remote_Notification_Action_Event`;
		case 'local_call':
			return `${prefix}_Local_Call_Action_Event`;
	}
};

/**
 * Gets the handler return type for a specific phase and spec.
 */
export const get_handler_return_type = (spec: Action_Spec, phase: Action_Phase): string => {
	// For request_response receive_request, handler returns the output
	if (spec.kind === 'request_response' && phase === 'receive_request') {
		const base_type = `Action_Outputs['${spec.method}']`;
		return `${base_type} | Promise<${base_type}>`;
	}

	// For local_call execute, handler returns the output
	if (spec.kind === 'local_call' && phase === 'execute') {
		const base_type = `Action_Outputs['${spec.method}']`;
		return spec.async ? `${base_type} | Promise<${base_type}>` : base_type;
	}

	// All other phases return void
	return spec.async ? 'void | Promise<void>' : 'void';
};

/**
 * Generates the phase handlers for an action spec.
 */
export const generate_phase_handlers = (
	spec: Action_Spec,
	executor: 'frontend' | 'backend',
	imports: Import_Builder,
): string => {
	const {method, kind} = spec;
	const phases = get_executor_phases(spec, executor);

	if (phases.length === 0) {
		return `${method}?: never`;
	}

	// Add necessary imports based on the action kind
	const event_type_name = get_action_event_type(kind, executor);
	const module =
		executor === 'frontend'
			? '$lib/frontend_action_event.js'
			: '$lib/server/backend_action_event.js';

	imports.add_type(module, event_type_name);
	imports.add_type('$lib/action_collections.js', 'Action_Inputs');
	imports.add_type('$lib/action_collections.js', 'Action_Outputs');

	// Build the parameterized event type
	let event_type: string;
	if (kind === 'request_response') {
		event_type = `${event_type_name}<'${method}', Action_Inputs['${method}'], Action_Outputs['${method}']>`;
	} else if (kind === 'remote_notification') {
		event_type = `${event_type_name}<'${method}', Action_Inputs['${method}']>`;
	} else {
		event_type = `${event_type_name}<'${method}', Action_Inputs['${method}'], Action_Outputs['${method}']>`;
	}

	// Generate handler definitions for each phase
	const phase_handlers = phases
		.map((phase: Action_Phase) => {
			const return_type = get_handler_return_type(spec, phase);
			return `${phase}?: (action_event: ${event_type}) => ${return_type}`;
		})
		.join(';\n\t\t');

	return `${method}?: {\n\t\t${phase_handlers};\n\t}`;
};

/**
 * Creates a file banner comment.
 */
export const create_banner = (origin_path: string): string =>
	`generated by ${origin_path} - DO NOT EDIT OR RISK LOST DATA`;
