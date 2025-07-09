import ollama from 'ollama';
import {dirname, join} from 'node:path';
import {format_file} from '@ryanatkn/gro/format_file.js';
import Anthropic from '@anthropic-ai/sdk';
import OpenAI from 'openai';
import {GoogleGenerativeAI} from '@google/generative-ai';
import {
	SECRET_ANTHROPIC_API_KEY,
	SECRET_GOOGLE_API_KEY,
	SECRET_OPENAI_API_KEY,
} from '$env/static/private';

import {
	format_ollama_messages,
	format_claude_messages,
	format_openai_messages,
	format_gemini_messages,
} from '$lib/server/ai_provider_utils.js';
import {to_completion_result} from '$lib/response_helpers.js';
import {Scoped_Fs} from '$lib/server/scoped_fs.js';
import {Action_Inputs, type Action_Outputs} from '$lib/action_collections.js';
import type {Backend} from '$lib/server/backend.js';
import type {Completion_Message} from '$lib/completion_types.js';
import type {Uuid} from '$lib/zod_helpers.js';
import {jsonrpc_errors} from '$lib/jsonrpc_errors.js';

export interface Completion_Handler_Options {
	model: string;
	completion_options: Completion_Options;
	completion_messages: Array<Completion_Message> | undefined;
	prompt: string;
	progress_token?: Uuid;
	backend: Backend;
}

// TODO refactor to a plugin/mod architecture

// TODO probably refactor the options construction to reduce duplication

// TODO parameterize - do we want these to be on the server, or keep the dependencies separated?
// maybe we could make this configured at the top level, and these instances would be shared?
// similar to dependency injection, the point being to let people configure dependencies that can be used by arbitrary code/mod
const anthropic = new Anthropic({apiKey: SECRET_ANTHROPIC_API_KEY});
const openai = new OpenAI({apiKey: SECRET_OPENAI_API_KEY});
const google = new GoogleGenerativeAI(SECRET_GOOGLE_API_KEY);

// TODO rework this into the params with a UI
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

export type Completion_Handler = (
	options: Completion_Handler_Options,
) => Promise<Action_Outputs['create_completion']>;

export const get_completion_handler = (
	provider_name: string,
	streaming: boolean,
): Completion_Handler => {
	switch (provider_name) {
		case 'ollama':
			return streaming ? handle_ollama_streaming : handle_ollama_non_streaming;
		case 'claude':
			return streaming ? handle_claude_streaming : handle_claude_non_streaming;
		case 'chatgpt':
			return streaming ? handle_chatgpt_streaming : handle_chatgpt_non_streaming;
		case 'gemini':
			return streaming ? handle_gemini_streaming : handle_gemini_non_streaming;
		default:
			throw jsonrpc_errors.invalid_params(`Unsupported provider: ${provider_name}`);
	}
};

// Ollama handlers
export const handle_ollama_streaming: Completion_Handler = async (options) => {
	const {model, completion_options, completion_messages, prompt, progress_token, backend} = options;
	if (!progress_token) {
		throw jsonrpc_errors.invalid_params('progress_token is required for streaming');
	}

	// TODO @many is this what we want to do? or error? needs to stream progress in the streaming case
	const listed = await ollama.list();
	if (!listed.models.some((m) => m.name === model)) {
		await ollama.pull({model}); // TODO handle stream
	}

	const response = await ollama.chat({
		model,
		// TODO
		// format,
		// keep_alive,
		stream: true,
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
		messages: format_ollama_messages(
			completion_options.system_message,
			completion_messages,
			prompt,
		),
	});

	let accumulated_content = '';
	let final_response;

	for await (const chunk of response) {
		console.log(`[create_completion] streaming chunk:`, chunk);

		// Accumulate the message content
		accumulated_content += chunk.message.content;

		// Send streaming progress notification to frontend
		console.log(
			'[create_completion] sending streaming notification:',
			progress_token,
			'chunk:',
			chunk,
		);
		void backend.api.completion_progress({
			// TODO see the other patterns, maybe the API should be parsing and this takes the input schema (same issue on frontend)
			chunk: Action_Inputs.completion_progress.shape.chunk.parse(chunk),
			_meta: {progressToken: progress_token},
		});

		// Store the final response data
		final_response = chunk;
	}

	console.log(
		`[create_completion] ollama streaming completed, final content length:`,
		accumulated_content.length,
	);

	// Create the final API response object
	const api_response = {
		...final_response, // TODO is this right?
		message: {
			...final_response?.message, // TODO is this right?
			content: accumulated_content,
		},
	};

	console.log(`ollama api_response`, api_response);
	return to_completion_result('ollama', model, api_response, progress_token);
};

export const handle_ollama_non_streaming: Completion_Handler = async (options) => {
	const {model, completion_options, completion_messages, prompt} = options;

	// TODO @many is this what we want to do? or error? needs to stream progress in the streaming case
	const listed = await ollama.list();
	if (!listed.models.some((m) => m.name === model)) {
		await ollama.pull({model}); // TODO handle stream
	}

	const response = await ollama.chat({
		model,
		// TODO
		// format,
		// keep_alive,
		stream: false,
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
		messages: format_ollama_messages(
			completion_options.system_message,
			completion_messages,
			prompt,
		),
	});

	console.log(`[create_completion] ollama non-streaming response:`, response);

	const api_response = {
		...response,
		message: {
			...response.message,
			content: response.message.content,
		},
	};

	console.log(`ollama api_response`, api_response);
	return to_completion_result('ollama', model, api_response);
};

// Claude handlers
export const handle_claude_streaming: Completion_Handler = async (options) => {
	const {model, completion_options, completion_messages, prompt, progress_token, backend} = options;
	if (!progress_token) {
		throw jsonrpc_errors.invalid_params('progress_token is required for streaming');
	}

	const stream = await anthropic.messages.create({
		model,
		stream: true,
		max_tokens: completion_options.output_token_max,
		temperature: completion_options.temperature,
		top_k: completion_options.top_k,
		top_p: completion_options.top_p,
		stop_sequences: completion_options.stop_sequences,
		system: completion_options.system_message,
		messages: format_claude_messages(completion_messages, prompt),
	});

	let accumulated_content = '';
	let final_event: any = null;
	let message_id = '';
	let final_usage: any = null;

	for await (const event of stream) {
		console.log(`[create_completion] claude streaming event:`, event);

		// Handle different event types
		if (event.type === 'message_start') {
			message_id = event.message.id;
		} else if (event.type === 'content_block_delta' && event.delta.type === 'text_delta') {
			accumulated_content += event.delta.text;

			// Send streaming progress notification to frontend
			void backend.api.completion_progress({
				chunk: {
					message: {
						content: event.delta.text,
						role: 'assistant', // TODO @api @many hardcoded role, which of these are correct if any?
					},
				},
				_meta: {progressToken: progress_token},
			});
		} else if (event.type === 'message_delta') {
			final_usage = event.usage;
			final_event = event;
		}
	}

	console.log(
		`[create_completion] claude streaming completed, final content length:`,
		accumulated_content.length,
	);

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

	console.log(`claude api_response`, api_response);
	return to_completion_result('claude', model, api_response, progress_token);
};

export const handle_claude_non_streaming: Completion_Handler = async (options) => {
	const {model, completion_options, completion_messages, prompt} = options;

	const response = await anthropic.messages.create({
		model,
		stream: false,
		max_tokens: completion_options.output_token_max,
		temperature: completion_options.temperature,
		top_k: completion_options.top_k,
		top_p: completion_options.top_p,
		stop_sequences: completion_options.stop_sequences,
		system: completion_options.system_message,
		messages: format_claude_messages(completion_messages, prompt),
	});

	console.log(`[create_completion] claude non-streaming response:`, response);

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

	console.log(`claude api_response`, api_response);
	return to_completion_result('claude', model, api_response);
};

// ChatGPT handlers
export const handle_chatgpt_streaming: Completion_Handler = async (options) => {
	const {model, completion_options, completion_messages, prompt, progress_token, backend} = options;
	if (!progress_token) {
		throw jsonrpc_errors.invalid_params('progress_token is required for streaming');
	}

	// TODO use responses API instead
	const stream = await openai.chat.completions.create({
		model,
		stream: true,
		max_completion_tokens: completion_options.output_token_max,
		temperature: model === 'o1-mini' ? undefined : completion_options.temperature,
		seed: completion_options.seed,
		top_p: completion_options.top_p,
		frequency_penalty: completion_options.frequency_penalty,
		presence_penalty: completion_options.presence_penalty,
		stop: completion_options.stop_sequences,
		messages: format_openai_messages(
			completion_options.system_message,
			completion_messages,
			prompt,
			model,
		),
	});

	let accumulated_content = '';
	let completion_id = '';
	let finish_reason: string | null = null;
	let final_usage: any = null;

	for await (const chunk of stream) {
		console.log(`[create_completion] openai streaming chunk:`, chunk);

		// Get ID from first chunk
		if (!completion_id && chunk.id) {
			completion_id = chunk.id;
		}

		// Extract content from choices
		const delta = chunk.choices[0]?.delta as
			| OpenAI.Chat.Completions.ChatCompletionChunk.Choice.Delta
			| undefined;
		if (delta?.content) {
			accumulated_content += delta.content;

			// Send streaming progress notification to frontend
			void backend.api.completion_progress({
				chunk: {
					message: {
						content: delta.content,
						role: 'assistant', // TODO @api @many hardcoded role, which of these are correct if any?
					},
				},
				_meta: {progressToken: progress_token},
			});
		}

		// Capture finish reason
		if (chunk.choices[0]?.finish_reason) {
			finish_reason = chunk.choices[0].finish_reason;
		}

		// Capture usage data
		if (chunk.usage) {
			final_usage = chunk.usage;
		}
	}

	console.log(
		`[create_completion] openai streaming completed, final content length:`,
		accumulated_content.length,
	);

	// Create the final API response object
	const api_response = {
		id: completion_id,
		object: 'chat.completion',
		created: Date.now() / 1000,
		model,
		choices: [
			{
				index: 0,
				message: {
					role: 'assistant', // TODO @api @many hardcoded role, which of these are correct if any?
					content: accumulated_content,
				},
				finish_reason: finish_reason || 'stop',
			},
		],
		usage: final_usage,
	};

	console.log(`openai api_response`, api_response);
	return to_completion_result('chatgpt', model, api_response, progress_token);
};

export const handle_chatgpt_non_streaming: Completion_Handler = async (options) => {
	const {model, completion_options, completion_messages, prompt} = options;

	// TODO use responses API instead
	const response = await openai.chat.completions.create({
		model,
		stream: false,
		max_completion_tokens: completion_options.output_token_max,
		temperature: model === 'o1-mini' ? undefined : completion_options.temperature,
		seed: completion_options.seed,
		top_p: completion_options.top_p,
		frequency_penalty: completion_options.frequency_penalty,
		presence_penalty: completion_options.presence_penalty,
		stop: completion_options.stop_sequences,
		messages: format_openai_messages(
			completion_options.system_message,
			completion_messages,
			prompt,
			model,
		),
	});

	console.log(`[create_completion] openai non-streaming response:`, response);

	const api_response = {
		id: response.id,
		object: response.object,
		created: response.created,
		model: response.model,
		choices: response.choices,
		usage: response.usage,
	};

	console.log(`openai api_response`, api_response);
	return to_completion_result('chatgpt', model, api_response);
};

// Gemini handlers
export const handle_gemini_streaming: Completion_Handler = async (options) => {
	const {model, completion_options, completion_messages, prompt, progress_token, backend} = options;
	if (!progress_token) {
		throw jsonrpc_errors.invalid_params('progress_token is required for streaming');
	}

	// TODO cache this by model?
	const google_model = google.getGenerativeModel({
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
	});

	const content = format_gemini_messages(completion_messages, prompt);

	const stream_result = await google_model.generateContentStream(content);

	let accumulated_content = '';
	let final_response: any = null;
	let usage_metadata: any = null;

	// Iterate over the stream
	for await (const chunk of stream_result.stream) {
		console.log(`[create_completion] gemini streaming chunk:`, chunk);

		try {
			// Extract text from the chunk - gemini chunks have a text() method
			const chunk_text = chunk.text();
			accumulated_content += chunk_text;

			// Send streaming progress notification to frontend
			void backend.api.completion_progress({
				chunk: {
					message: {
						content: chunk_text,
						role: 'assistant', // TODO @api @many hardcoded role, which of these are correct if any?
					},
				},
				_meta: {progressToken: progress_token},
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

	console.log(
		`[create_completion] gemini streaming completed, final content length:`,
		accumulated_content.length,
	);

	// Create the final API response object
	const api_response = {
		text: accumulated_content,
		candidates: final_response?.candidates || null,
		function_calls: final_response?.functionCalls?.() || null,
		prompt_feedback: final_response?.promptFeedback || null,
		usage_metadata,
	};

	console.log(`gemini api_response`, api_response);
	return to_completion_result('gemini', model, api_response, progress_token);
};

export const handle_gemini_non_streaming: Completion_Handler = async (options) => {
	const {model, completion_options, completion_messages, prompt} = options;

	// TODO cache this by model?
	const google_model = google.getGenerativeModel({
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
	});

	const content = format_gemini_messages(completion_messages, prompt);

	const result = await google_model.generateContent(content);
	const response = result.response;

	console.log(`[create_completion] gemini non-streaming response:`, response);

	const accumulated_content = response.text();

	// Create the final API response object
	const api_response = {
		text: accumulated_content,
		candidates: response.candidates || null,
		function_calls: response.functionCalls() || null,
		prompt_feedback: response.promptFeedback || null,
		usage_metadata: response.usageMetadata || null,
	};

	console.log(`gemini api_response`, api_response);
	return to_completion_result('gemini', model, api_response);
};

// TODO @db refactor
export const save_completion_response_to_disk = async (
	input: Action_Inputs['create_completion'],
	output: Action_Outputs['create_completion'],
	dir: string,
	scoped_fs: Scoped_Fs,
): Promise<void> => {
	// includes `Date.now()` for sorting purposes
	const filename = `${input.completion_request.provider_name}__${Date.now()}__${input.completion_request.model}.json`; // TODO include model data in these

	const path = join(dir, filename);

	const json = {input, output};

	await write_json(path, json, scoped_fs);
};
// TODO @db refactor
const write_json = async (path: string, json: unknown, scoped_fs: Scoped_Fs): Promise<void> => {
	// Check if directory exists and create it if needed
	if (!(await scoped_fs.exists(path))) {
		await scoped_fs.mkdir(dirname(path), {recursive: true});
	}

	const formatted = await format_file(JSON.stringify(json), {parser: 'json'});

	// Use Scoped_Fs for writing the file
	console.log('writing json', path, formatted.length);
	await scoped_fs.write_file(path, formatted);
};
