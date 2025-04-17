import type {Strip} from '$lib/strip.svelte.js';

// TODO look into refactoring this to be more correct, it's only used to calculate the token count for a tape by combining all chat strips
/**
 * Renders the tape's content by combining all chat strips
 * in a format suitable for token counting and display.
 */
export const render_tape = (strips: IterableIterator<Strip>): string => {
	let s = '';

	for (const strip of strips) {
		if (!strip.enabled) continue;
		if (s) s += '\n\n';
		s += `${strip.role}: ${strip.content}`;
	}

	return s;
};
