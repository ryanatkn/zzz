import ollama from 'ollama';

import {Backend_Provider, type Completion_Handler_Options} from '$lib/server/backend_provider.js';
import {to_completion_result} from '$lib/response_helpers.js';
import {Action_Inputs, type Action_Outputs} from '$lib/action_collections.js';
import type {Completion_Message} from '$lib/completion_types.js';

export class Ollama_Backend_Provider extends Backend_Provider {
	readonly name = 'ollama';

	format_messages(
		system_message: string,
		completion_messages: Array<Completion_Message> | undefined,
		prompt: string,
	): Array<{role: string; content: string}> {
		return [
			{role: 'system', content: system_message},
			...(completion_messages || []),
			{role: 'user', content: prompt},
		];
	}

	async handle_streaming(
		options: Completion_Handler_Options,
	): Promise<Action_Outputs['create_completion']> {
		const {model, completion_options, completion_messages, prompt, progress_token, backend} =
			options;
		this.validate_streaming_requirements(progress_token);

		// TODO @many is this what we want to do? or error? needs to stream progress in the streaming case
		const listed = await ollama.list();
		if (!listed.models.some((m) => m.name === model)) {
			await ollama.pull({model}); // TODO handle stream
		}

		const response = await ollama.chat(
			this.#create_ollama_chat_options(
				model,
				completion_options,
				completion_messages,
				prompt,
				true,
			),
		);

		let accumulated_content = '';
		let final_response;

		for await (const chunk of response) {
			this.log_streaming_chunk(chunk);

			// Accumulate the message content
			accumulated_content += chunk.message.content;

			// Send streaming progress notification to frontend
			console.log(
				'[create_completion] sending streaming notification:',
				progress_token,
				'chunk:',
				chunk,
			);
			void this.send_streaming_progress(
				backend,
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

	async handle_non_streaming(
		options: Completion_Handler_Options,
	): Promise<Action_Outputs['create_completion']> {
		const {model, completion_options, completion_messages, prompt} = options;

		// TODO @many is this what we want to do? or error? needs to stream progress in the streaming case
		const listed = await ollama.list();
		if (!listed.models.some((m) => m.name === model)) {
			await ollama.pull({model}); // TODO handle stream
		}

		const response = await ollama.chat(
			this.#create_ollama_chat_options(
				model,
				completion_options,
				completion_messages,
				prompt,
				false,
			),
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

	#create_ollama_chat_options<T extends boolean>(
		model: string,
		completion_options: Completion_Handler_Options['completion_options'],
		completion_messages: Array<Completion_Message> | undefined,
		prompt: string,
		stream: T,
	) {
		return {
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
			messages: this.format_messages(
				completion_options.system_message,
				completion_messages,
				prompt,
			),
		};
	}
}
