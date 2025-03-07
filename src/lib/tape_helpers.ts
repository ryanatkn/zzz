import type {Chat_Message} from '$lib/chat_message.svelte.js';

// TODO look into refactoring this to be more correct, it's only used to calculate the token count for a tape by combining all chat messages
/**
 * Renders the tape's content by combining all chat messages
 * in a format suitable for token counting and display.
 */
export const render_tape = (messages: Array<Chat_Message>): string => {
	if (!messages.length) return '';

	let s = '';

	for (const message of messages) {
		if (s) s += '\n\n';
		s += `${message.role}: ${message.content}`;
	}

	return s;
};
