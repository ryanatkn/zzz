import {GoogleGenerativeAI} from '@google/generative-ai';
import {SECRET_GOOGLE_API_KEY} from '$env/static/private';

import {Backend_Provider, type Completion_Handler_Options} from '$lib/server/backend_provider.js';
import {to_completion_result} from '$lib/response_helpers.js';
import type {Action_Outputs} from '$lib/action_collections.js';
import type {Completion_Message} from '$lib/completion_types.js';

export class Gemini_Backend_Provider extends Backend_Provider {
	readonly name = 'gemini';
	private google = new GoogleGenerativeAI(SECRET_GOOGLE_API_KEY);

	format_messages(
		completion_messages: Array<Completion_Message> | undefined,
		prompt: string,
	): string {
		// TODO does this have to be a string?
		if (completion_messages && completion_messages.length > 0) {
			return (
				completion_messages.map((m) => `${m.role}: ${m.content}`).join('\n\n') +
				'\n\nuser: ' +
				prompt
			);
		}

		return prompt;
	}

	async handle_streaming(
		options: Completion_Handler_Options,
	): Promise<Action_Outputs['create_completion']> {
		const {model, completion_options, completion_messages, prompt, progress_token, backend} =
			options;
		this.validate_streaming_requirements(progress_token);

		// TODO cache this by model?
		const google_model = this.google.getGenerativeModel(
			this.#create_gemini_model_options(model, completion_options),
		);

		const content = this.format_messages(completion_messages, prompt);

		const stream_result = await google_model.generateContentStream(content);

		let accumulated_content = '';
		let final_response: any = null;
		let usage_metadata: any = null;

		// Iterate over the stream
		for await (const chunk of stream_result.stream) {
			this.log_streaming_chunk(chunk);

			try {
				// Extract text from the chunk - gemini chunks have a text() method
				const chunk_text = chunk.text();
				accumulated_content += chunk_text;

				// Send streaming progress notification to frontend
				void this.send_streaming_progress(backend, progress_token, {
					// TODO @many other chunk data
					message: {
						content: chunk_text,
						role: 'assistant',
					},
				});
			} catch (error) {
				// Text extraction might fail if prompt was blocked or other issues
				console.error('[create_completion] Failed to extract text from gemini chunk:', error);
			}

			// Store the latest response data
			final_response = chunk;
			if (chunk.usageMetadata) {
				usage_metadata = chunk.usageMetadata;
			}
		}

		this.log_streaming_completion(accumulated_content.length);

		// Create the final API response object
		const api_response = {
			text: accumulated_content,
			candidates: final_response?.candidates || null,
			function_calls: final_response?.functionCalls?.() || null,
			prompt_feedback: final_response?.promptFeedback || null,
			usage_metadata,
		};

		this.log_api_response(api_response);
		return to_completion_result('gemini', model, api_response, progress_token);
	}

	async handle_non_streaming(
		options: Completion_Handler_Options,
	): Promise<Action_Outputs['create_completion']> {
		const {model, completion_options, completion_messages, prompt} = options;

		// TODO cache this by model?
		const google_model = this.google.getGenerativeModel(
			this.#create_gemini_model_options(model, completion_options),
		);

		const content = this.format_messages(completion_messages, prompt);

		const result = await google_model.generateContent(content);
		const response = result.response;

		this.log_non_streaming_response(response);

		const accumulated_content = response.text();

		// Create the final API response object
		const api_response = {
			text: accumulated_content,
			candidates: response.candidates || null,
			function_calls: response.functionCalls() || null,
			prompt_feedback: response.promptFeedback || null,
			usage_metadata: response.usageMetadata || null,
		};

		this.log_api_response(api_response);
		return to_completion_result('gemini', model, api_response);
	}

	#create_gemini_model_options(
		model: string,
		completion_options: Completion_Handler_Options['completion_options'],
	) {
		return {
			model,
			systemInstruction: completion_options.system_message,
			// TODO
			// tools,
			// toolConfig
			generationConfig: {
				maxOutputTokens: completion_options.output_token_max,
				temperature: completion_options.temperature,
				topK: completion_options.top_k,
				topP: completion_options.top_p,
				frequencyPenalty: completion_options.frequency_penalty,
				presencePenalty: completion_options.presence_penalty,
				stopSequences: completion_options.stop_sequences,
			},
		};
	}
}
