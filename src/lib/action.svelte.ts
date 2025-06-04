import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Completion_Response, Completion_Request} from '$lib/completion_types.js';
import {Action_Method} from '$lib/action_metatypes.js';
import {Diskfile_Change, Diskfile_Path, Serializable_Source_File} from '$lib/diskfile_types.js';
import {to_completion_response_text} from '$lib/response_helpers.js';
import {to_preview} from '$lib/helpers.js';
import {Action_Json, Action_Kind} from '$lib/action_types.js';
import {
	Jsonrpc_Request,
	Jsonrpc_Response,
	Jsonrpc_Notification,
	Jsonrpc_Error_Message,
	type Jsonrpc_Request_Id,
} from '$lib/jsonrpc.js';
import {action_spec_by_method} from '$lib/action_collections.js';
import type {Action_Spec} from '$lib/action_spec.js';

export interface Action_Options extends Cell_Options<typeof Action_Json> {}

/**
 * Represents a single action in the system, tracking its full lifecycle.
 * For request/response actions, a single Action tracks both the request and response.
 * For notifications and local calls, it tracks just the single message.
 */
export class Action extends Cell<typeof Action_Json> {
	method: Action_Method = $state()!;

	// Store the full JSON-RPC messages
	// data: Action_Data;
	jsonrpc_request: Jsonrpc_Request | undefined = $state.raw();
	jsonrpc_response: Jsonrpc_Response | Jsonrpc_Error_Message | undefined = $state.raw();
	jsonrpc_notification: Jsonrpc_Notification | undefined = $state.raw();

	readonly spec: Action_Spec = $derived.by(() => {
		const s = action_spec_by_method.get(this.method);
		if (!s) throw new Error(`Missing action spec for method '${this.method}'`);
		return s;
	});

	kind: Action_Kind = $derived(this.spec.kind);

	// Computed properties for easy access
	readonly jsonrpc_message_id: Jsonrpc_Request_Id | null = $derived(
		this.jsonrpc_request?.id ?? null,
	);

	readonly has_response: boolean = $derived(!!this.jsonrpc_response);
	readonly has_error: boolean = $derived(
		!!this.jsonrpc_response && 'error' in this.jsonrpc_response,
	);

	readonly is_complete: boolean = $derived(
		this.spec.kind !== 'request_response' || this.has_response,
	);

	// Extract params and result for convenience
	readonly params: any = $derived.by(() => {
		if (this.jsonrpc_request) return this.jsonrpc_request.params;
		if (this.jsonrpc_notification) return this.jsonrpc_notification.params;
		return undefined;
	});

	readonly result: any = $derived.by(() => {
		if (this.jsonrpc_response && 'result' in this.jsonrpc_response) {
			return this.jsonrpc_response.result;
		}
		return undefined;
	});

	readonly error: any = $derived.by(() => {
		if (this.jsonrpc_response && 'error' in this.jsonrpc_response) {
			return this.jsonrpc_response.error;
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
		if (this.is_ping && this.result?.ping_id) {
			return this.result.ping_id;
		}
		return undefined;
	});

	readonly completion_request: Completion_Request | undefined = $derived.by(() => {
		if (this.is_prompt && this.params?.completion_request) {
			return this.params.completion_request;
		}
		return undefined;
	});

	readonly completion_response: Completion_Response | undefined = $derived.by(() => {
		if (this.is_prompt && this.result?.completion_response) {
			return this.result.completion_response;
		}
		return undefined;
	});

	readonly path: Diskfile_Path | undefined = $derived.by(() => {
		if (this.is_file_related && this.params?.path) {
			return this.params.path;
		}
		return undefined;
	});

	readonly content: string | undefined = $derived.by(() => {
		if (this.method === 'update_diskfile' && this.params?.content) {
			return this.params.content;
		}
		return undefined;
	});

	readonly change: Diskfile_Change | undefined = $derived.by(() => {
		if (this.method === 'filer_change' && this.params?.change) {
			return this.params.change;
		}
		return undefined;
	});

	readonly source_file: Serializable_Source_File | undefined = $derived.by(() => {
		if (this.method === 'filer_change' && this.params?.source_file) {
			return this.params.source_file;
		}
		return undefined;
	});

	readonly data: Record<string, any> | undefined = $derived.by(() => {
		if (this.is_session && this.result?.data) {
			return this.result.data;
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
		this.init();
	}

	add_request(request: Jsonrpc_Request): void {
		if (this.spec.kind !== 'request_response') {
			throw new Error(`Cannot add request to action of kind '${this.spec.kind}'`);
		}
		this.jsonrpc_request = request;
	}

	add_response(response: Jsonrpc_Response | Jsonrpc_Error_Message): void {
		if (this.spec.kind !== 'request_response') {
			throw new Error(`Cannot add response to action of kind '${this.spec.kind}'`);
		}
		this.jsonrpc_response = response;
	}

	add_notification(notification: Jsonrpc_Notification): void {
		if (this.spec.kind !== 'remote_notification') {
			throw new Error(`Cannot add notification to action of kind '${this.spec.kind}'`);
		}
		this.jsonrpc_notification = notification;
	}
}

export const Action_Schema = z.instanceof(Action);
