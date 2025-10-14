import type {Part_Union} from '$lib/part.svelte.js';
import {GLYPH_PART, GLYPH_FILE} from '$lib/glyphs.js';

export const PART_GLYPHS = {
	text: GLYPH_PART,
	diskfile: GLYPH_FILE,
} satisfies Record<Part_Union['type'], string>;

export const get_part_type_glyph = (part: Part_Union): string =>
	PART_GLYPHS[part.type] ?? GLYPH_PART; // eslint-disable-line @typescript-eslint/no-unnecessary-condition
