import type {Svg_Data} from '@ryanatkn/fuz/Svg.svelte';
import {base} from '$app/paths';
import {
	GLYPH_CAPABILITY,
	GLYPH_CHAT,
	GLYPH_FILE,
	GLYPH_LOG,
	GLYPH_MODEL,
	GLYPH_PROMPT,
	GLYPH_PROVIDER,
	GLYPH_SETTINGS,
} from '$lib/glyphs.js';
import {zzz_logo} from '@ryanatkn/fuz/logos.js';

// TODO fuz api for this in its library nav? look into it at the library -> docs rename
export interface Nav_Item {
	group: string;
	items: Array<{
		label: string;
		href: string;
		icon: string | Svg_Data;
	}>;
}

export const main_nav_items_default: Array<Nav_Item> = [
	{
		group: 'main',
		items: [
			{label: 'chats', href: `${base}/chats`, icon: GLYPH_CHAT},
			{label: 'prompts', href: `${base}/prompts`, icon: GLYPH_PROMPT},
			{label: 'files', href: `${base}/files`, icon: GLYPH_FILE},
		],
	},
	{
		group: 'ai',
		items: [
			{label: 'models', href: `${base}/models`, icon: GLYPH_MODEL},
			{label: 'providers', href: `${base}/providers`, icon: GLYPH_PROVIDER},
		],
	},
	{
		group: 'system',
		items: [
			{label: 'about', href: `${base}/about`, icon: zzz_logo},
			{label: 'log', href: `${base}/log`, icon: GLYPH_LOG},
			{label: 'capabilities', href: `${base}/capabilities`, icon: GLYPH_CAPABILITY},
			{label: 'settings', href: `${base}/settings`, icon: GLYPH_SETTINGS},
		],
	},
];
