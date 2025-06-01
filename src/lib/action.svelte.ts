import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Completion_Response, Completion_Request} from '$lib/completion_types.js';
import {Action_Message_Type, Action_Method} from '$lib/action_metatypes.js';
import {Diskfile_Change, Diskfile_Path, Serializable_Source_File} from '$lib/diskfile_types.js';
import {to_completion_response_text} from '$lib/response_helpers.js';
import {to_preview} from '$lib/helpers.js';
import {Action_Json, Action_Kind} from '$lib/action_types.js';
import type {Jsonrpc_Request_Id} from '$lib/jsonrpc.js';

export interface Action_Options extends Cell_Options<typeof Action_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type

// TODO this class is a mess, probably refactor all of this to have generic immutable data
export class Action extends Cell<typeof Action_Json> {
	type: Action_Message_Type = $state()!;
	method: Action_Method = $state()!;
	params: any = $state.raw();
	// TODO BLOCK @api this needs to have the full jsonrpc message, and there's two for requests and responses (how to handle the notification one? separately?)
	// maybe one typesafe object that covers all three kinds of actions?
	jsonrpc_message_id: Jsonrpc_Request_Id = $state()!;

	kind: Action_Kind = $state()!; // TODO maybe store the spec here for convenience, instead or or in addition to the kind?

	// Store data based on action type
	data: Record<string, any> | undefined = $state.raw();
	ping_id: Uuid | undefined = $state();
	completion_request: Completion_Request | undefined = $state.raw();
	completion_response: Completion_Response | undefined = $state.raw();
	path: Diskfile_Path | undefined = $state();
	content: string | undefined = $state();
	change: Diskfile_Change | undefined = $state();
	source_file: Serializable_Source_File | undefined = $state.raw();

	readonly display_name: string = $derived(`${this.method} (${this.kind})`);

	// TODO hacky, refactor, probably removing these from this class, find a different way to get type safety
	readonly is_ping: boolean = $derived(this.method === 'ping');
	readonly is_prompt: boolean = $derived(this.method === 'submit_completion');
	readonly is_session: boolean = $derived(this.method === 'load_session');
	readonly is_file_related: boolean = $derived(
		this.method === 'update_diskfile' ||
			this.method === 'delete_diskfile' ||
			this.method === 'filer_change',
	);

	readonly prompt_data: Completion_Request | null = $derived(
		this.is_prompt && this.completion_request ? this.completion_request : null,
	);

	readonly completion_data: Completion_Response | null = $derived(
		this.is_prompt && this.completion_response ? this.completion_response : null,
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
		if (!this.is_prompt) return 'Not a completion action';

		if (!this.completion_text) return 'No completion';

		return to_preview(this.completion_text);
	});

	constructor(options: Action_Options) {
		super(Action_Json, options);
		this.init();
	}
}

export const Action_Schema = z.instanceof(Action);
