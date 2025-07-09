// @slop claude_opus_4

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
	action_event: Action_Event_Data.optional(),
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
	action_event: Action_Event_Data | undefined = $state.raw();

	readonly spec: Action_Spec_Union = $derived.by(() => {
		const s = Action_Specs[this.method] as Action_Spec_Union | undefined; // TODO refactor
		if (!s) throw new Error(`Missing action spec for method '${this.method}'`);
		return s;
	});

	readonly kind: Action_Kind = $derived(this.spec.kind);

	readonly has_error = $derived(!!this.action_event?.error);

	readonly pending = $derived(this.action_event?.step === 'handling');
	readonly failed = $derived(this.action_event?.step === 'failed');
	readonly success = $derived(this.action_event?.step === 'handled');

	constructor(options: Action_Options) {
		super(Action_Json, options);
		this.init();
	}

	// TODO @api temporary hacking this, rethink the reactivity/action_event usage with this class
	unlisten_to_action_event: (() => void) | undefined;
	listen_to_action_event(action_event: Action_Event): void {
		this.unlisten_to_action_event?.();
		this.unlisten_to_action_event = action_event.observe((new_data) => {
			this.action_event = new_data;
		});
	}

	// TODO automatic cleanup with a cell API
	override dispose(): void {
		super.dispose();
		this.unlisten_to_action_event?.();
	}
}

export const Action_Schema = z.instanceof(Action);
