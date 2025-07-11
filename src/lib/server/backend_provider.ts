import type {Backend} from '$lib/server/backend.js';
import type {Completion_Message} from '$lib/completion_types.js';
import type {Action_Inputs, Action_Outputs} from '$lib/action_collections.js';
import type {Uuid} from '$lib/zod_helpers.js';
import {jsonrpc_errors} from '$lib/jsonrpc_errors.js';

// TODO proper logging

export type Completion_Handler = (
	options: Completion_Handler_Options,
) => Promise<Action_Outputs['create_completion']>;

// TODO refactor, how?
export interface Completion_Options {
	frequency_penalty?: number;
	output_token_max: number;
	presence_penalty?: number;
	seed?: number;
	stop_sequences?: Array<string>;
	system_message: string;
	temperature?: number;
	top_k?: number;
	top_p?: number;
}

// TODO refactor, how?
export interface Completion_Handler_Options {
	model: string;
	completion_options: Completion_Options;
	completion_messages: Array<Completion_Message> | undefined;
	prompt: string;
	backend: Backend;
	progress_token?: Uuid;
}

export abstract class Backend_Provider {
	abstract readonly name: string;

	abstract handle_streaming(
		options: Completion_Handler_Options,
	): Promise<Action_Outputs['create_completion']>;
	abstract handle_non_streaming(
		options: Completion_Handler_Options,
	): Promise<Action_Outputs['create_completion']>;

	get_handler(streaming: boolean): Completion_Handler {
		return streaming ? this.handle_streaming.bind(this) : this.handle_non_streaming.bind(this);
	}

	/** Validates that progress_token is provided for streaming requests. */
	protected validate_streaming_requirements(progress_token?: Uuid): asserts progress_token {
		if (!progress_token) {
			throw jsonrpc_errors.invalid_params('progress_token is required for streaming');
		}
	}

	/** Sends streaming progress notification to frontend */
	protected async send_streaming_progress(
		backend: Backend,
		progress_token: Uuid,
		chunk: Action_Inputs['completion_progress']['chunk'],
	): Promise<void> {
		await backend.api.completion_progress({
			chunk,
			_meta: {progressToken: progress_token},
		});
	}

	/** Logs streaming chunk information */
	protected log_streaming_chunk(chunk: unknown): void {
		console.log(`[create_completion] ${this.name} streaming chunk:`, chunk);
	}

	/** Logs streaming completion information */
	protected log_streaming_completion(accumulated_length: number): void {
		console.log(
			`[create_completion] ${this.name} streaming completed, final content length:`,
			accumulated_length,
		);
	}

	/** Logs non-streaming response information */
	protected log_non_streaming_response(response: unknown): void {
		console.log(`[create_completion] ${this.name} non-streaming response:`, response);
	}

	/** Logs final API response information */
	protected log_api_response(api_response: unknown): void {
		console.log(`${this.name} api_response`, api_response);
	}
}
