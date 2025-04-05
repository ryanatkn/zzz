import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import {
	Payload_Json,
	Completion_Response,
	Completion_Request,
	type Payload_Direction,
	type Payload_Type,
	type Diskfile_Change,
} from '$lib/payload_types.js';
import {Diskfile_Path, Source_File} from '$lib/diskfile_types.js';
import {to_completion_response_text} from '$lib/response_helpers.js';
import {to_preview} from '$lib/helpers.js';

// Constants for preview length and formatting
export const PAYLOAD_DATE_FORMAT = 'MMM d, p';
export const PAYLOAD_TIME_FORMAT = 'p';

export interface Payload_Options extends Cell_Options<typeof Payload_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

// TODO think about splitting out a different non-reactive version
// that only handles the static expectation,
// but then another for dynamic usage? is there even such a thing of a payload changing?
// if not shouldn't we just remove the $state below?
export class Payload extends Cell<typeof Payload_Json> {
	type: Payload_Type = $state()!;
	direction: Payload_Direction = $state()!;

	// Store data based on payload type
	data: Record<string, any> | undefined = $state();
	ping_id: Uuid | undefined = $state();
	completion_request: Completion_Request | undefined = $state();
	completion_response: Completion_Response | undefined = $state();
	path: Diskfile_Path | undefined = $state();
	content: string | undefined = $state(); // TODO BLOCK derived token count like with diskfiles?
	change: Diskfile_Change | undefined = $state();
	source_file: Source_File | undefined = $state();

	display_name: string = $derived(`${this.type} (${this.direction})`);

	// TODO maybe change these to be located on `this.type` as a `Payload_Type_Name` class which JSON serializes to the string `Payload_Type` but at runtime has properties like these:
	is_ping: boolean = $derived(this.type === 'ping');
	is_pong: boolean = $derived(this.type === 'pong');
	is_prompt: boolean = $derived(this.type === 'send_prompt');
	is_completion: boolean = $derived(this.type === 'completion_response');
	is_session: boolean = $derived(this.type === 'load_session' || this.type === 'loaded_session');
	is_file_related: boolean = $derived(
		this.type === 'update_diskfile' ||
			this.type === 'delete_diskfile' ||
			this.type === 'filer_change',
	);

	prompt_data: Completion_Request | null = $derived(
		this.is_prompt && this.completion_request ? this.completion_request : null,
	);

	completion_data: Completion_Response | null = $derived(
		this.is_completion && this.completion_response ? this.completion_response : null,
	);

	completion_text: string | null | undefined = $derived(
		this.completion_data ? to_completion_response_text(this.completion_data) : null,
	);

	prompt_preview: string = $derived.by(() => {
		if (!this.is_prompt) return 'Not a prompt payload';

		const prompt = this.prompt_data?.prompt;
		if (!prompt) return 'No prompt';

		return to_preview(prompt);
	});

	completion_preview: string = $derived.by(() => {
		if (!this.is_completion) return 'Not a completion payload';

		if (!this.completion_text) return 'No completion';

		return to_preview(this.completion_text);
	});

	constructor(options: Payload_Options) {
		super(Payload_Json, options);

		// Initialize decoders with type-specific handlers
		this.decoders = {
			completion_request: (value) =>
				this.type === 'send_prompt' ? Completion_Request.parse(value) : undefined,
			completion_response: (value) =>
				this.type === 'completion_response' ? Completion_Response.parse(value) : undefined,
			ping_id: (value) => (this.type === 'pong' ? Uuid.parse(value) : undefined),
			path: (value) =>
				this.type === 'update_diskfile' || this.type === 'delete_diskfile'
					? Diskfile_Path.parse(value)
					: undefined,
		};

		// Initialize base properties
		this.init();
	}
}

export const Payload_Schema = z.instanceof(Payload);
