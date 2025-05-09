import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {get_datetime_now, Uuid} from '$lib/zod_helpers.js';
import {Action_Direction, Completion_Response, Completion_Request} from '$lib/schemas.js';
import {Action_Name} from '$lib/action_types.js';
import type {Action_Client, Action_Server} from '$lib/action_collections.js';
import {Diskfile_Change, Diskfile_Path, Source_File} from '$lib/diskfile_types.js';
import {to_completion_response_text} from '$lib/response_helpers.js';
import {to_preview} from '$lib/helpers.js';
import {Cell_Json} from '$lib/cell_types.js';

// Constants for preview length and formatting
export const ACTION_DATE_FORMAT = 'MMM d, p';
export const ACTION_TIME_FORMAT = 'p';

// TODO BLOCK maybe generate from the registry? `schemas` instance maybe, instead of `* as schemas`?
// Mapping for action directions
export const action_directions: Record<string, Action_Direction> = {
	ping: 'client',
	pong: 'server',
	load_session: 'client',
	loaded_session: 'server',
	send_prompt: 'client',
	completion_response: 'server',
	filer_change: 'server',
	update_diskfile: 'client',
	delete_diskfile: 'client',
	create_directory: 'client',
};

// TODO BLOCK replace with the actions proxy
// Helper function to create an action with json representation
export const create_action_json = (
	action: Action_Client | Action_Server,
	direction: Action_Direction,
): Action_Json => {
	return {
		...action,
		direction,
		created: get_datetime_now(),
	} as Action_Json;
};

// TODO remove?
// Helper to get the direction for an action
export const get_action_direction = (type: Action_Name): Action_Direction =>
	action_directions[type];

export const Action_Json = Cell_Json.extend({
	name: Action_Name,
	direction: Action_Direction,
	// Optional fields with proper type checking
	ping_id: Uuid.optional(),
	completion_request: Completion_Request.optional(),
	completion_response: Completion_Response.optional(),
	path: Diskfile_Path.optional(),
	content: z.string().optional(),
	change: Diskfile_Change.optional(),
	source_file: Source_File.optional(),
	data: z.record(z.string(), z.any()).optional(),
}).strict();
export type Action_Json = z.infer<typeof Action_Json>;
export type Action_Json_Input = z.input<typeof Action_Json>;

export interface Action_Options extends Cell_Options<typeof Action_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

// TODO think about splitting out a different non-reactive version
// that only handles the static expectation,
// but then another for dynamic usage? is there even such a thing of an action changing?
// if not shouldn't we just remove the $state below?
export class Action extends Cell<typeof Action_Json> {
	name: Action_Name = $state()!;
	direction: Action_Direction = $state()!;

	// Store data based on action type
	data: Record<string, any> | undefined = $state();
	ping_id: Uuid | undefined = $state();
	completion_request: Completion_Request | undefined = $state();
	completion_response: Completion_Response | undefined = $state();
	path: Diskfile_Path | undefined = $state();
	content: string | undefined = $state();
	change: Diskfile_Change | undefined = $state();
	source_file: Source_File | undefined = $state();

	readonly display_name: string = $derived(`${this.name} (${this.direction})`);

	// TODO maybe change these to be located on `this.name` as a `Action_Name_Name` class
	// which JSON serializes to the string `Action_Name`
	// but at runtime has properties like these:
	readonly is_ping: boolean = $derived(this.name === 'ping');
	readonly is_pong: boolean = $derived(this.name === 'pong');
	readonly is_prompt: boolean = $derived(this.name === 'send_prompt');
	readonly is_completion: boolean = $derived(this.name === 'completion_response');
	readonly is_session: boolean = $derived(
		this.name === 'load_session' || this.name === 'loaded_session',
	);
	readonly is_file_related: boolean = $derived(
		this.name === 'update_diskfile' ||
			this.name === 'delete_diskfile' ||
			this.name === 'filer_change',
	);

	readonly prompt_data: Completion_Request | null = $derived(
		this.is_prompt && this.completion_request ? this.completion_request : null,
	);

	readonly completion_data: Completion_Response | null = $derived(
		this.is_completion && this.completion_response ? this.completion_response : null,
	);

	readonly completion_text: string | null | undefined = $derived(
		this.completion_data ? to_completion_response_text(this.completion_data) : null,
	);

	readonly prompt_preview: string = $derived.by(() => {
		if (!this.is_prompt) return 'Not a prompt action';

		const prompt = this.prompt_data?.prompt;
		if (!prompt) return 'No prompt';

		return to_preview(prompt);
	});

	readonly completion_preview: string = $derived.by(() => {
		if (!this.is_completion) return 'Not a completion action';

		if (!this.completion_text) return 'No completion';

		return to_preview(this.completion_text);
	});

	constructor(options: Action_Options) {
		super(Action_Json, options);

		// Initialize decoders with type-specific handlers
		this.decoders = {
			completion_request: (value) =>
				this.name === 'send_prompt' ? Completion_Request.parse(value) : undefined,
			completion_response: (value) =>
				this.name === 'completion_response' ? Completion_Response.parse(value) : undefined,
			ping_id: (value) => (this.name === 'pong' ? Uuid.parse(value) : undefined),
			path: (value) =>
				this.name === 'update_diskfile' || this.name === 'delete_diskfile'
					? Diskfile_Path.parse(value)
					: undefined,
		};

		// Initialize base properties
		this.init();
	}
}

export const Action_Schema = z.instanceof(Action);
