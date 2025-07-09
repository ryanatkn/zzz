import type {Strip} from '$lib/strip.svelte.js';
import type {Completion_Message} from '$lib/completion_types.js';
import {to_completion_response_text} from '$lib/response_helpers.js';
import type {Strip_Role} from '$lib/strip_types.js';

// TODO refactor where?
/**
 * Renders a single message with an XML tag that includes the role attribute.
 */
export const render_message_with_role = (
	role: Strip_Role,
	content: string,
	tag = 'message',
): string => `<${tag} role="${role}">${content}</${tag}>`;

/**
 * Renders the tape's content by combining all chat strips
 * in a format suitable for token counting and display.
 *
 * @param tag - the XML tag to use, default is 'message' (consider 'Completion_Message'?
 * 	'message' is better for end users)
 */
export const render_tape_to_string = (strips: Iterable<Strip>, tag = 'message'): string => {
	let s = '';

	for (const strip of strips) {
		if (!strip.enabled) continue;
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
