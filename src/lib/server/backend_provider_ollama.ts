import ollama, {Ollama} from 'ollama';
import {find_cli} from '@ryanatkn/gro/cli.js';

import {
	Backend_Provider_Local,
	type Completion_Handler_Options,
} from '$lib/server/backend_provider.js';
import {to_completion_result} from '$lib/response_helpers.js';
import {Action_Inputs, type Action_Outputs} from '$lib/action_collections.js';
import type {Completion_Message} from '$lib/completion_types.js';
import {type Provider_Status, PROVIDER_ERROR_NOT_INSTALLED} from '$lib/provider_types.js';

export class Backend_Provider_Ollama extends Backend_Provider_Local<Ollama> {
	readonly name = 'ollama';

	protected override create_client(): void {
		this.client = find_cli('ollama') ? ollama : null;
	}

	override async load_status(reload: boolean = false): Promise<Provider_Status> {
		// Return cached status if available and reload not requested
		if (!reload && this.provider_status !== null) {
			return this.provider_status;
		}

		const cli = find_cli('ollama');
		if (!cli) {
			const status: Provider_Status = {
				name: this.name,
				available: false,
				error: PROVIDER_ERROR_NOT_INSTALLED,
				checked_at: Date.now(),
			};
			this.provider_status = status;
			return status;
		}

		try {
			await this.client!.list();
			const status: Provider_Status = {
				name: this.name,
				available: true,
				checked_at: Date.now(),
			};
			this.provider_status = status;
			return status;
		} catch (error) {
			console.error('[ollama_backend_provider] error checking availability:', error);
			const error_message = error instanceof Error ? error.message : String(error);
			const status: Provider_Status = {
				name: this.name,
				available: false,
				error: error_message,
				checked_at: Date.now(),
			};
			this.provider_status = status;
			return status;
		}
	}

	async handle_streaming_completion(
		options: Completion_Handler_Options,
	): Promise<Action_Outputs['completion_create']> {
		const {model, completion_options, completion_messages, prompt, progress_token} = options;
		this.validate_streaming_requirements(progress_token);

		// TODO @many is this what we want to do? or error? needs to stream progress in the streaming case
		const listed = await ollama.list();
		if (!listed.models.some((m) => m.name === model)) {
			await ollama.pull({model}); // TODO handle stream
		}

		// TODO should we support this?
		// ollama.generate({prompt})
		const response = await ollama.chat(
			create_ollama_chat_options(model, completion_options, completion_messages, prompt, true),
		);

		let accumulated_content = '';
		let final_response;

		for await (const chunk of response) {
			this.log_streaming_chunk(chunk);

			// Accumulate the message content
			accumulated_content += chunk.message.content;

			// Send streaming progress notification to frontend
			void this.send_streaming_progress(
				progress_token,
				// TODO see the other patterns, maybe the API should be parsing and this takes the input schema (same issue on frontend)
				Action_Inputs.completion_progress.shape.chunk.parse(chunk),
			);

			// Store the final response data
			final_response = chunk;
		}

		this.log_streaming_completion(accumulated_content.length);

		// Create the final API response object
		const api_response = {
			...final_response, // TODO is this right?
			message: {
				...final_response?.message, // TODO is this right?
				content: accumulated_content,
			},
		};

		this.log_api_response(api_response);
		return to_completion_result('ollama', model, api_response, progress_token);
	}

	async handle_non_streaming_completion(
		options: Completion_Handler_Options,
	): Promise<Action_Outputs['completion_create']> {
		const {model, completion_options, completion_messages, prompt} = options;

		// TODO @many is this what we want to do? or error? needs to stream progress in the streaming case
		const listed = await ollama.list();
		if (!listed.models.some((m) => m.name === model)) {
			await ollama.pull({model}); // TODO handle stream
		}

		const response = await ollama.chat(
			create_ollama_chat_options(model, completion_options, completion_messages, prompt, false),
		);

		this.log_non_streaming_response(response);

		const api_response = {
			...response,
			message: {
				...response.message,
				content: response.message.content,
			},
		};

		this.log_api_response(api_response);
		return to_completion_result('ollama', model, api_response);
	}
}

const create_ollama_chat_options = <T extends boolean>(
	model: string,
	completion_options: Completion_Handler_Options['completion_options'],
	completion_messages: Array<Completion_Message> | undefined,
	prompt: string,
	stream: T,
) => ({
	model,
	// TODO
	// format,
	// keep_alive,
	stream,
	// think,
	// tools,
	options: {
		temperature: completion_options.temperature,
		seed: completion_options.seed,
		num_predict: completion_options.output_token_max,
		top_k: completion_options.top_k,
		top_p: completion_options.top_p,
		frequency_penalty: completion_options.frequency_penalty,
		presence_penalty: completion_options.presence_penalty,
		stop: completion_options.stop_sequences,
	},
	messages: to_messages(completion_options.system_message, completion_messages, prompt),
});

const to_messages = (
	system_message: string,
	completion_messages: Array<Completion_Message> | undefined,
	prompt: string,
): Array<{role: string; content: string}> => {
	return [
		{role: 'system', content: system_message},
		...(completion_messages || []),
		{role: 'user', content: prompt},
	];
};
