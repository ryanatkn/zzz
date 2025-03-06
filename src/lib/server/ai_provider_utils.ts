import type {Tape_History_Message} from '$lib/message_types.js';

/**
 * Format messages for the Ollama API.
 */
export const format_ollama_messages = (
	system_message: string,
	tape_history: Array<Tape_History_Message> | undefined,
	prompt: string,
): Array<{role: string; content: string}> => {
	return [
		{role: 'system', content: system_message},
		...(tape_history || []),
		{role: 'user', content: prompt},
	];
};

/**
 * Format messages for the Claude API.
 */
export const format_claude_messages = (
	tape_history: Array<Tape_History_Message> | undefined,
	prompt: string,
): Array<{role: 'user' | 'assistant'; content: Array<{type: 'text'; text: string}>}> => {
	const claude_messages = [];

	// Add tape history with proper typing for Claude API
	if (tape_history) {
		for (const tape_history_message of tape_history) {
			if (tape_history_message.role !== 'system') {
				// Claude expects 'user' or 'assistant' roles only
				claude_messages.push({
					role: tape_history_message.role,
					content: [{type: 'text' as const, text: tape_history_message.content}],
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
	tape_history: Array<Tape_History_Message> | undefined,
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
	if (tape_history) {
		for (const tape_history_message of tape_history) {
			openai_messages.push({
				// Type assertion to match OpenAI's expected roles
				role: tape_history_message.role,
				content: tape_history_message.content,
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
	tape_history: Array<Tape_History_Message> | undefined,
	prompt: string,
): string => {
	// For Gemini, format history as a string if available
	if (tape_history && tape_history.length > 0) {
		return tape_history.map((m) => `${m.role}: ${m.content}`).join('\n\n') + '\n\nuser: ' + prompt;
	}

	return prompt;
};
