import type {Tape_Message} from '$lib/action_types.js';

/**
 * Format messages for the Ollama API.
 */
export const format_ollama_messages = (
	system_message: string,
	tape_messages: Array<Tape_Message> | undefined,
	prompt: string,
): Array<{role: string; content: string}> => {
	return [
		{role: 'system', content: system_message},
		...(tape_messages || []),
		{role: 'user', content: prompt},
	];
};

/**
 * Format messages for the Claude API.
 */
export const format_claude_messages = (
	tape_messages: Array<Tape_Message> | undefined,
	prompt: string,
): Array<{role: 'user' | 'assistant'; content: Array<{type: 'text'; text: string}>}> => {
	const claude_messages = [];

	// Add tape history with proper typing for Claude API
	if (tape_messages) {
		for (const tape_messages_message of tape_messages) {
			if (tape_messages_message.role !== 'system') {
				// Claude expects 'user' or 'assistant' roles only
				claude_messages.push({
					role: tape_messages_message.role,
					content: [{type: 'text' as const, text: tape_messages_message.content}],
				});
			}
		}
	}

	// Add the current message
	claude_messages.push({
		role: 'user' as const,
		content: [{type: 'text' as const, text: prompt}],
	});

	return claude_messages;
};

/**
 * Format messages for the OpenAI API.
 */
export const format_openai_messages = (
	system_message: string,
	tape_messages: Array<Tape_Message> | undefined,
	prompt: string,
	model: string,
): Array<{role: 'system' | 'user' | 'assistant'; content: string}> => {
	const openai_messages = [];

	// Only add system message if the model supports it
	if (model !== 'o1-mini') {
		openai_messages.push({
			role: 'system' as const,
			content: system_message,
		});
	}

	// Add tape history
	if (tape_messages) {
		for (const tape_messages_message of tape_messages) {
			openai_messages.push({
				// Type assertion to match OpenAI's expected roles
				role: tape_messages_message.role,
				content: tape_messages_message.content,
			});
		}
	}

	// Add the current message
	openai_messages.push({
		role: 'user' as const,
		content: prompt,
	});

	return openai_messages;
};

/**
 * Format messages for the Gemini API.
 */
export const format_gemini_messages = (
	tape_messages: Array<Tape_Message> | undefined,
	prompt: string,
): string => {
	// For Gemini, format history as a string if available
	if (tape_messages && tape_messages.length > 0) {
		return tape_messages.map((m) => `${m.role}: ${m.content}`).join('\n\n') + '\n\nuser: ' + prompt;
	}

	return prompt;
};
