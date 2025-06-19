// @slop claude_opus_4

import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Action_Method} from '$lib/action_metatypes.js';
import {Action_Kind} from '$lib/action_types.js';
import {action_spec_by_method} from '$lib/action_collections.js';
import type {Action_Spec} from '$lib/action_spec.js';
import {type Action_Event, parse_action_event} from '$lib/action_event.js';
import {HANDLED} from '$lib/cell_helpers.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Action_Event_Data} from '$lib/action_event_data.js';

// TODO this isnt in action_types.ts because of circular dependencies, idk what pattern is best yet
export const Action_Json = Cell_Json.extend({
	method: Action_Method,
	action_event: Action_Event_Data,
});
export type Action_Json = z.infer<typeof Action_Json>;
export type Action_Json_Input = z.input<typeof Action_Json>;

export interface Action_Options extends Cell_Options<typeof Action_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

/**
 * Represents a single action in the system, tracking its full lifecycle through action events.
 */
export class Action extends Cell<typeof Action_Json> {
	method: Action_Method = $state()!;

	action_event: Action_Event | undefined = $state.raw();

	readonly spec: Action_Spec = $derived.by(() => {
		const s = action_spec_by_method.get(this.method);
		if (!s) throw new Error(`Missing action spec for method '${this.method}'`);
		return s;
	});

	kind: Action_Kind = $derived(this.spec.kind);

	readonly data = $derived(this.action_event?.data);

	readonly has_error = $derived(!!this.data?.error);

	constructor(options: Action_Options) {
		super(Action_Json, options);

		this.decoders = {
			action_event: (data) => {
				if (data) {
					// TODO maybe try/catch in the base class?
					try {
						this.action_event = parse_action_event(data, this.app);
					} catch (error) {
						console.error('Failed to reconstruct action event:', error);
					}
				}
				return HANDLED;
			},
		};

		this.init();
	}

	update_from_event(action_event: Action_Event): void {
		this.action_event?.set_data(action_event.toJSON());
	}
}

export const Action_Schema = z.instanceof(Action);
