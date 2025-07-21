// @slop Claude Opus 4

import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Action_Method} from '$lib/action_metatypes.js';
import {Action_Kind} from '$lib/action_types.js';
import {Action_Specs} from '$lib/action_collections.js';
import type {Action_Spec_Union} from '$lib/action_spec.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Action_Event_Data} from '$lib/action_event_data.js';
import type {Action_Event} from '$lib/action_event.js';

// TODO this isnt in action_types.ts because of circular dependencies, idk what pattern is best yet
export const Action_Json = Cell_Json.extend({
	method: Action_Method,
	action_event_data: Action_Event_Data.optional(),
});
export type Action_Json = z.infer<typeof Action_Json>;
export type Action_Json_Input = z.input<typeof Action_Json>;

export interface Action_Options extends Cell_Options<typeof Action_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

/**
 * Represents a single action in the system, tracking its full lifecycle through action events.
 */
export class Action extends Cell<typeof Action_Json> {
	method: Action_Method = $state()!;

	// TODO maybe use a decoder to make this an `Action_Event`
	action_event_data: Action_Event_Data | undefined = $state.raw();

	readonly spec: Action_Spec_Union = $derived.by(() => {
		const s = Action_Specs[this.method] as Action_Spec_Union | undefined; // TODO refactor
		if (!s) throw new Error(`Missing action spec for method '${this.method}'`);
		return s;
	});

	readonly kind: Action_Kind = $derived(this.spec.kind);

	readonly has_error = $derived(!!this.action_event_data?.error);

	// TODO this being convoluted is indicative of a larger issue
	// that we may want to rethink with the flow of action events with phase+step
	readonly pending = $derived.by(() => {
		if (!this.action_event_data) {
			return true; // no data yet means pending
		}

		const {step, phase, kind} = this.action_event_data;

		// For request_response actions, only the final phase (receive_response)
		// with a terminal step (handled/failed) means the action is complete
		if (kind === 'request_response') {
			return !(phase === 'receive_response' && (step === 'handled' || step === 'failed'));
		} else {
			// For other kinds, just check if step is terminal
			return step !== 'handled' && step !== 'failed';
		}
	});
	readonly failed = $derived.by(() => {
		if (!this.action_event_data) {
			return false; // no data yet means not failed
		}

		const {step, kind} = this.action_event_data;

		// For request_response actions, failure can happen in any phase
		if (kind === 'request_response') {
			return step === 'failed';
		} else {
			// For other kinds, step === 'failed' means failed
			return step === 'failed';
		}
	});
	readonly success = $derived.by(() => {
		if (!this.action_event_data) {
			return false; // no data yet means not successful
		}

		const {step, phase, kind} = this.action_event_data;

		// For request_response actions, success means completing the full cycle
		if (kind === 'request_response') {
			return phase === 'receive_response' && step === 'handled';
		} else {
			// For other kinds, step === 'handled' means success
			return step === 'handled';
		}
	});

	constructor(options: Action_Options) {
		super(Action_Json, options);
		this.init();
	}

	// TODO @api temporary hacking this, rethink the reactivity/action_event usage with this class
	unlisten_to_action_event: (() => void) | undefined;
	action_event: Action_Event | undefined;
	listen_to_action_event(action_event: Action_Event): () => void {
		this.unlisten_to_action_event?.();
		this.action_event = action_event;
		const unobserve = action_event.observe((new_data) => {
			this.action_event_data = new_data;
		});
		this.unlisten_to_action_event = () => {
			unobserve();
			this.unlisten_to_action_event = undefined;
			this.action_event = undefined;
		};
		return this.unlisten_to_action_event;
	}

	// TODO automatic cleanup with a cell API
	override dispose(): void {
		super.dispose();
		this.unlisten_to_action_event?.();
	}
}

export const Action_Schema = z.instanceof(Action);
