import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Completion_Response, Completion_Request} from '$lib/completion_types.js';
import {Action_Method} from '$lib/action_metatypes.js';
import {Diskfile_Change, Diskfile_Path, Serializable_Source_File} from '$lib/diskfile_types.js';
import {to_completion_response_text} from '$lib/response_helpers.js';
import {to_preview} from '$lib/helpers.js';
import {
	Action_Json,
	Action_Kind,
	Action_Data,
	type Action_Input,
	type Action_Output,
} from '$lib/action_types.js';
import {
	Jsonrpc_Request,
	Jsonrpc_Response,
	Jsonrpc_Notification,
	Jsonrpc_Error_Message,
	type Jsonrpc_Request_Id,
} from '$lib/jsonrpc.js';
import {action_spec_by_method} from '$lib/action_collections.js';
import type {Action_Spec} from '$lib/action_spec.js';

// TODO BLOCK @api probably refactor with "step" like with the server_action_event.ts,
// see also client_action_event.ts and action_types.ts -- would get clarity and type safety,
// but we may need to rework the `Action` and `Client_Action_Event` stuff to be more like the `Server_Action_Event`

export interface Action_Options extends Cell_Options<typeof Action_Json> {}

/**
 * Represents a single action in the system, tracking its full lifecycle.
 * For request/response actions, a single Action tracks both the request and response.
 * For notifications and local calls, it tracks just the single message.
 */
export class Action extends Cell<typeof Action_Json> {
	method: Action_Method = $state()!;

	/**
	 * The action data containing messages based on the action kind.
	 * Uses a discriminated union for type safety.
	 */
	data: Action_Data | undefined = $state.raw();

	readonly spec: Action_Spec = $derived.by(() => {
		const s = action_spec_by_method.get(this.method);
		if (!s) throw new Error(`Missing action spec for method '${this.method}'`);
		return s;
	});

	kind: Action_Kind = $derived(this.spec.kind);

	// Computed properties for easy access
	readonly jsonrpc_message_id: Jsonrpc_Request_Id | null = $derived.by(() => {
		if (!this.data) return null;
		if (this.data.kind === 'request_response') {
			return this.data.request.id;
		}
		return null;
	});

	readonly has_response: boolean = $derived(
		this.data?.kind === 'request_response' && !!this.data.response,
	);

	readonly has_error: boolean = $derived.by(() => {
		if (!this.data || this.data.kind !== 'request_response') return false;
		return !!this.data.response && 'error' in this.data.response;
	});

	readonly is_complete: boolean = $derived(
		this.spec.kind !== 'request_response' || this.has_response,
	);

	// Extract input/output for convenience - these work across all action kinds
	readonly input: Action_Input | undefined = $derived(this.data?.input);
	readonly output: Action_Output | undefined = $derived(this.data?.output);

	// Extract params and result for convenience (backwards compatibility)
	readonly params: any = $derived.by(() => {
		return this.data?.input;
	});

	readonly result: any = $derived.by(() => {
		return this.data?.output;
	});

	readonly error: any = $derived.by(() => {
		if (!this.data || this.data.kind !== 'request_response') return undefined;
		return this.data.response && 'error' in this.data.response
			? this.data.response.error
			: undefined;
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

	readonly session_data: Record<string, any> | undefined = $derived.by(() => {
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

	add_request(request: Jsonrpc_Request, input: Action_Input): void {
		if (this.spec.kind !== 'request_response') {
			throw new Error(`Cannot add request to action of kind '${this.spec.kind}'`);
		}
		this.data = {
			kind: 'request_response',
			input,
			request,
		};
	}

	add_response(response: Jsonrpc_Response | Jsonrpc_Error_Message): void {
		if (this.spec.kind !== 'request_response') {
			throw new Error(`Cannot add response to action of kind '${this.spec.kind}'`);
		}
		if (!this.data || this.data.kind !== 'request_response') {
			throw new Error('Cannot add response without request');
		}
		this.data = {
			...this.data,
			output: 'result' in response ? response.result : undefined,
			response,
		};
	}

	add_notification(notification: Jsonrpc_Notification, input: Action_Input): void {
		if (this.spec.kind !== 'remote_notification') {
			throw new Error(`Cannot add notification to action of kind '${this.spec.kind}'`);
		}
		this.data = {
			kind: 'remote_notification',
			input,
			output: undefined, // Notifications have no output
			notification,
		};
	}

	set_local_call_input(input: Action_Input): void {
		if (this.spec.kind !== 'local_call') {
			throw new Error(`Cannot set local call input on action of kind '${this.spec.kind}'`);
		}
		this.data = {
			kind: 'local_call',
			input,
			output: undefined,
		};
	}

	set_local_call_output(output: Action_Output): void {
		if (this.spec.kind !== 'local_call') {
			throw new Error(`Cannot set local call output on action of kind '${this.spec.kind}'`);
		}
		this.data = {
			...(this.data as any),
			output,
		};
	}
}

export const Action_Schema = z.instanceof(Action);
