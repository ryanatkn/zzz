import Anthropic from '@anthropic-ai/sdk';
import {SECRET_ANTHROPIC_API_KEY} from '$env/static/private';

import {
	Backend_Provider_Remote,
	type Backend_Provider_Options,
	type Completion_Handler_Options,
} from '$lib/server/backend_provider.js';
import {to_completion_result} from '$lib/response_helpers.js';
import type {Action_Outputs} from '$lib/action_collections.js';
import type {Completion_Message} from '$lib/completion_types.js';

export class Backend_Provider_Claude extends Backend_Provider_Remote<Anthropic> {
	readonly name = 'claude';

	constructor(options: Backend_Provider_Options) {
		super({...options, api_key: options.api_key ?? (SECRET_ANTHROPIC_API_KEY || null)});
	}

	protected override create_client(): void {
		this.client = this.api_key ? new Anthropic({apiKey: this.api_key}) : null;
	}

	async handle_streaming_completion(
		options: Completion_Handler_Options,
	): Promise<Action_Outputs['completion_create']> {
		const {model, completion_options, completion_messages, prompt, progress_token} = options;
		this.validate_streaming_requirements(progress_token);

		const stream = await this.get_client().messages.create(
			create_claude_completion_options(
				model,
				completion_options,
				completion_messages,
				prompt,
				true,
			),
		);

		let accumulated_content = '';
		let final_event: any = null;
		let message_id = '';
		let final_usage: any = null;

		for await (const event of stream) {
			this.log_streaming_chunk(event);

			// Handle different event types
			if (event.type === 'message_start') {
				message_id = event.message.id;
			} else if (event.type === 'content_block_delta' && event.delta.type === 'text_delta') {
				accumulated_content += event.delta.text;

				// Send streaming progress notification to frontend
				void this.send_streaming_progress(progress_token, {
					// TODO @many other chunk data
					message: {
						role: 'assistant',
						content: event.delta.text,
					},
				});
			} else if (event.type === 'message_delta') {
				final_usage = event.usage;
				final_event = event;
			}
		}

		this.log_streaming_completion(accumulated_content.length);

		// Create the final API response object
		const api_response = {
			id: message_id,
			type: 'message',
			role: 'assistant', // TODO @api @many hardcoded role, which of these are correct if any?
			content: [{type: 'text', text: accumulated_content}],
			model,
			stop_reason: final_event?.delta?.stop_reason || 'end_turn',
			stop_sequence: final_event?.delta?.stop_sequence || null,
			usage: final_usage,
		};

		this.log_api_response(api_response);
		return to_completion_result('claude', model, api_response, progress_token);
	}

	async handle_non_streaming_completion(
		options: Completion_Handler_Options,
	): Promise<Action_Outputs['completion_create']> {
		const {model, completion_options, completion_messages, prompt} = options;

		const response = await this.get_client().messages.create(
			create_claude_completion_options(
				model,
				completion_options,
				completion_messages,
				prompt,
				false,
			),
		);

		this.log_non_streaming_response(response);

		const api_response = {
			id: response.id,
			type: 'message',
			role: response.role,
			content: response.content,
			model: response.model,
			stop_reason: response.stop_reason,
			stop_sequence: response.stop_sequence,
			usage: response.usage,
		};

		this.log_api_response(api_response);
		return to_completion_result('claude', model, api_response);
	}
}

const create_claude_completion_options = <T extends boolean>(
	model: string,
	completion_options: Completion_Handler_Options['completion_options'],
	completion_messages: Array<Completion_Message> | undefined,
	prompt: string,
	stream: T,
) => ({
	model,
	stream,
	max_tokens: completion_options.output_token_max,
	temperature: completion_options.temperature,
	top_k: completion_options.top_k,
	top_p: completion_options.top_p,
	stop_sequences: completion_options.stop_sequences,
	system: completion_options.system_message,
	messages: to_messages(completion_messages, prompt),
});

// TODO @many cleanup with better data structures/helpers
const to_messages = (
	completion_messages: Array<Completion_Message> | undefined,
	prompt: string,
): Array<{role: 'user' | 'assistant'; content: Array<{type: 'text'; text: string}>}> => {
	const claude_messages: Array<{
		role: 'user' | 'assistant';
		content: Array<{type: 'text'; text: string}>;
	}> = [];

	// Add thread history with proper typing for Claude API
	if (completion_messages) {
		for (const message of completion_messages) {
			if (message.role !== 'system') {
				// Claude expects 'user' or 'assistant' roles only
				claude_messages.push({
					role: message.role as 'user' | 'assistant', // TODO maybe parse?
					content: [{type: 'text', text: message.content}],
				});
			}
		}
	}

	// Add the current message
	claude_messages.push({
		role: 'user',
		content: [{type: 'text', text: prompt}],
	});

	return claude_messages;
};
