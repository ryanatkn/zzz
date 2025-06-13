// @slop claude_opus_4
// action.svelte.ts

import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Completion_Response, Completion_Request} from '$lib/completion_types.js';
import {Action_Method} from '$lib/action_metatypes.js';
import {Diskfile_Change, Diskfile_Path, Serializable_Source_File} from '$lib/diskfile_types.js';
import {to_completion_response_text} from '$lib/response_helpers.js';
import {to_preview} from '$lib/helpers.js';
import {Action_Json, Action_Kind} from '$lib/action_types.js';
import type {Jsonrpc_Request_Id} from '$lib/jsonrpc.js';
import {action_spec_by_method} from '$lib/action_collections.js';
import type {Action_Spec} from '$lib/action_spec.js';
import {
	frontend_action_event_from_json,
	type Frontend_Action_Event,
} from '$lib/frontend_action_event.js';
import {HANDLED} from '$lib/cell_helpers.js';

export interface Action_Options extends Cell_Options<typeof Action_Json> {}

/**
 * Represents a single action in the system, tracking its full lifecycle through action events.
 */
export class Action extends Cell<typeof Action_Json> {
	method: Action_Method = $state()!;

	action_event: Frontend_Action_Event | undefined = $state.raw();

	readonly spec: Action_Spec = $derived.by(() => {
		const s = action_spec_by_method.get(this.method);
		if (!s) throw new Error(`Missing action spec for method '${this.method}'`);
		return s;
	});

	kind: Action_Kind = $derived(this.spec.kind);

	readonly data = $derived(this.action_event?.data);

	readonly jsonrpc_message_id: Jsonrpc_Request_Id | null = $derived.by(() => {
		const d = this.data;
		if (d?.kind === 'request_response' && d.step === 'handled' && d.phase === 'send_request') {
			return d.request.id;
		}
		return null;
	});

	readonly has_response: boolean = $derived.by(() => {
		const d = this.data;
		return d?.kind === 'request_response' && d.phase === 'receive_response' && !!d.response;
	});

	readonly has_error: boolean = $derived.by(() => {
		const d = this.data;
		if (d?.kind === 'request_response' && d.phase === 'receive_response' && d.response) {
			return 'error' in d.response;
		}
		return false;
	});

	readonly is_complete: boolean = $derived(this.action_event?.is_complete() ?? false);

	readonly input = $derived(this.data?.input);
	readonly output = $derived.by(() => {
		const d = this.data;
		if (d && 'output' in d) {
			return d.output;
		}
		return undefined;
	});

	readonly error = $derived.by(() => {
		const d = this.data;
		if (
			d?.kind === 'request_response' &&
			d.phase === 'receive_response' &&
			d.response &&
			'error' in d.response
		) {
			return d.response.error;
		}
		return undefined;
	});

	readonly display_name: string = $derived(`${this.method} (${this.spec.kind})`);

	readonly is_ping: boolean = $derived(this.method === 'ping');
	readonly is_prompt: boolean = $derived(this.method === 'submit_completion');
	readonly is_session: boolean = $derived(this.method === 'load_session');
	readonly is_file_related: boolean = $derived(
		this.method === 'update_diskfile' ||
			this.method === 'delete_diskfile' ||
			this.method === 'filer_change',
	);

	// TODO move all of this, shouldn't be here, just doing this as a hack to see stuff onscreen
	readonly ping_id: Uuid | undefined = $derived.by(() => {
		if (
			this.is_ping &&
			this.output &&
			typeof this.output === 'object' &&
			'ping_id' in this.output
		) {
			return this.output.ping_id;
		}
		return undefined;
	});

	readonly completion_request: Completion_Request | undefined = $derived.by(() => {
		if (
			this.is_prompt &&
			this.input &&
			typeof this.input === 'object' &&
			'completion_request' in this.input
		) {
			return this.input.completion_request;
		}
		return undefined;
	});

	readonly completion_response: Completion_Response | undefined = $derived.by(() => {
		if (
			this.is_prompt &&
			this.output &&
			typeof this.output === 'object' &&
			'completion_response' in this.output
		) {
			return this.output.completion_response;
		}
		return undefined;
	});

	readonly path: Diskfile_Path | undefined = $derived.by(() => {
		if (
			this.is_file_related &&
			this.input &&
			typeof this.input === 'object' &&
			'path' in this.input
		) {
			return this.input.path;
		}
		return undefined;
	});

	readonly content: string | undefined = $derived.by(() => {
		if (
			this.method === 'update_diskfile' &&
			this.input &&
			typeof this.input === 'object' &&
			'content' in this.input
		) {
			return this.input.content;
		}
		return undefined;
	});

	readonly change: Diskfile_Change | undefined = $derived.by(() => {
		if (
			this.method === 'filer_change' &&
			this.input &&
			typeof this.input === 'object' &&
			'change' in this.input
		) {
			return this.input.change;
		}
		return undefined;
	});

	readonly source_file: Serializable_Source_File | undefined = $derived.by(() => {
		if (
			this.method === 'filer_change' &&
			this.input &&
			typeof this.input === 'object' &&
			'source_file' in this.input
		) {
			return this.input.source_file;
		}
		return undefined;
	});

	readonly session_data: Record<string, any> | undefined = $derived.by(() => {
		if (
			this.is_session &&
			this.output &&
			typeof this.output === 'object' &&
			'data' in this.output
		) {
			return this.output.data;
		}
		return undefined;
	});

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

		this.decoders = {
			action_event: (data) => {
				if (data) {
					try {
						this.action_event = frontend_action_event_from_json(data, this.app);
					} catch (error) {
						console.error('Failed to reconstruct action event:', error);
					}
				}
				return HANDLED;
			},
		};

		this.init();
	}
}

export const Action_Schema = z.instanceof(Action);
