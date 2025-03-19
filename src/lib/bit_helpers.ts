import type {Bit_Type} from '$lib/bit.svelte.js';
import {GLYPH_BIT, GLYPH_FILE, GLYPH_LIST} from '$lib/glyphs.js';

export const BIT_GLYPHS = {
	text: GLYPH_BIT,
	diskfile: GLYPH_FILE,
	sequence: GLYPH_LIST,
} satisfies Record<Bit_Type['type'], string>;

/**
 * Get the appropriate glyph for a bit type
 */
export const get_bit_type_glyph = (bit: Bit_Type): string => BIT_GLYPHS[bit.type] ?? GLYPH_BIT; // eslint-disable-line @typescript-eslint/no-unnecessary-condition
