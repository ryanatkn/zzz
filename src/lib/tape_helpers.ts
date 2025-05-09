import type {Strip} from '$lib/strip.svelte.js';
import type {Tape_Message} from '$lib/action_types.js';
import {to_completion_response_text} from '$lib/response_helpers.js';

// TODO look into refactoring this to be more correct, it's only used to calculate the token count for a tape by combining all chat strips
/**
 * Renders the tape's content by combining all chat strips
 * in a format suitable for token counting and display.
 */
export const render_tape_to_string = (strips: IterableIterator<Strip>): string => {
	let s = '';

	for (const strip of strips) {
		if (!strip.enabled) continue;
		if (s) s += '\n\n';
		s += `${strip.role}: ${strip.content}`;
	}

	return s;
};

/**
 * Creates a tape history array for model consumption from a collection of strips.
 * Normalizes content for assistant strips with responses.
 */
export const render_tape_messages = (
	strips: IterableIterator<Strip>,
	tape_messages: Array<Tape_Message> = [],
): Array<Tape_Message> => {
	for (const strip of strips) {
		if (!strip.enabled) continue;

		tape_messages.push({
			role: strip.role,
			content:
				strip.role === 'assistant' && strip.response
					? to_completion_response_text(strip.response) || ''
					: strip.content,
		});
	}

	return tape_messages;
};
