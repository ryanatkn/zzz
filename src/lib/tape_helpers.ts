import type {Strip} from '$lib/strip.svelte.js';
import type {Completion_Message, Completion_Role} from '$lib/completion_types.js';
import {to_completion_response_text} from '$lib/response_helpers.js';

// TODO refactor where?
/**
 * Renders a single message with an XML tag that includes the role attribute.
 */
export const render_message_with_role = (
	role: Completion_Role,
	content: string,
	tag = 'message',
): string => `<${tag} role="${role}">${content}</${tag}>`;

export const render_messages_to_string = (
	strips: Iterable<{role: Completion_Role; content: string; enabled?: boolean}>,
	tag = 'message',
): string => {
	let s = '';

	for (const strip of strips) {
		if (strip.enabled === false) continue;

		if (s) s += '\n\n';
		s += render_message_with_role(strip.role, strip.content, tag);
	}

	return s;
};

/**
 * Creates a tape history array for model consumption from a collection of strips.
 * Normalizes content for assistant strips with responses.
 */
export const render_completion_messages = (
	strips: Iterable<Strip>,
	completion_messages: Array<Completion_Message> = [],
): Array<Completion_Message> => {
	for (const strip of strips) {
		if (!strip.enabled) continue;

		completion_messages.push({
			role: strip.role,
			content:
				strip.role === 'assistant' && strip.response
					? to_completion_response_text(strip.response) || ''
					: strip.content,
		});
	}

	return completion_messages;
};
