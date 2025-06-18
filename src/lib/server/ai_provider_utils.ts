import type {Completion_Message} from '$lib/completion_types.js';

/**
 * Format messages for the Ollama API.
 */
export const format_ollama_messages = (
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

/**
 * Format messages for the Claude API.
 */
export const format_claude_messages = (
	completion_messages: Array<Completion_Message> | undefined,
	prompt: string,
): Array<{role: 'user' | 'assistant'; content: Array<{type: 'text'; text: string}>}> => {
	const claude_messages = [];

	// Add tape history with proper typing for Claude API
	if (completion_messages) {
		for (const message of completion_messages) {
			if (message.role !== 'system') {
				// Claude expects 'user' or 'assistant' roles only
				claude_messages.push({
					role: message.role,
					content: [{type: 'text' as const, text: message.content}],
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
	completion_messages: Array<Completion_Message> | undefined,
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
	if (completion_messages) {
		for (const message of completion_messages) {
			openai_messages.push({
				// Type assertion to match OpenAI's expected roles
				role: message.role,
				content: message.content,
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
	completion_messages: Array<Completion_Message> | undefined,
	prompt: string,
): string => {
	// For Gemini, format history as a string if available
	if (completion_messages && completion_messages.length > 0) {
		return (
			completion_messages.map((m) => `${m.role}: ${m.content}`).join('\n\n') + '\n\nuser: ' + prompt
		);
	}

	return prompt;
};
