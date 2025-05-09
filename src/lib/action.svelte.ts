import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Completion_Response, Completion_Request} from '$lib/completion_types.js';
import {Action_Method} from '$lib/action_metatypes.js';
import {Diskfile_Change, Diskfile_Path, Source_File} from '$lib/diskfile_types.js';
import {to_completion_response_text} from '$lib/response_helpers.js';
import {to_preview} from '$lib/helpers.js';
import {Action_Direction} from '$lib/action_spec.js';
import {Action_Json} from './action_types.js';

export interface Action_Options extends Cell_Options<typeof Action_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

// TODO think about splitting out a different non-reactive version
// that only handles the static expectation,
// but then another for dynamic usage? is there even such a thing of an action changing?
// if not shouldn't we just remove the $state below?
export class Action extends Cell<typeof Action_Json> {
	method: Action_Method = $state()!;
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

	readonly display_name: string = $derived(`${this.method} (${this.direction})`);

	// TODO hacky, refactor
	readonly is_ping: boolean = $derived(this.method === 'ping');
	readonly is_pong: boolean = $derived(this.method === 'pong');
	readonly is_prompt: boolean = $derived(this.method === 'send_prompt');
	readonly is_completion: boolean = $derived(this.method === 'completion_response');
	readonly is_session: boolean = $derived(
		this.method === 'load_session' || this.method === 'loaded_session',
	);
	readonly is_file_related: boolean = $derived(
		this.method === 'update_diskfile' ||
			this.method === 'delete_diskfile' ||
			this.method === 'filer_change',
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
				this.method === 'send_prompt' ? Completion_Request.parse(value) : undefined,
			completion_response: (value) =>
				this.method === 'completion_response' ? Completion_Response.parse(value) : undefined,
			ping_id: (value) => (this.method === 'pong' ? Uuid.parse(value) : undefined),
			path: (value) =>
				this.method === 'update_diskfile' || this.method === 'delete_diskfile'
					? Diskfile_Path.parse(value)
					: undefined,
		};

		// Initialize base properties
		this.init();
	}
}

export const Action_Schema = z.instanceof(Action);
