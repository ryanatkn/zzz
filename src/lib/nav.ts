import type {Svg_Data} from '@ryanatkn/fuz/Svg.svelte';
import {base} from '$app/paths';
import {zzz_logo} from '@ryanatkn/fuz/logos.js';
import {page} from '$app/state';

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
import type {Frontend} from '$lib/frontend.svelte.js';

export interface Nav_Link_Item {
	label: string;
	href: string;
	icon: string | Svg_Data;
}

// TODO fuz api for this in its library nav? look into it at the library -> docs rename
export interface Nav_Item {
	group: string;
	items: Array<Nav_Link_Item>;
}

// TODO generalize this pattern, it's one part of a hacky fix
// for the chats/prompts links to show the last selected id,
// if any, when not on the route directly.
// See also the `onNavigate` fix in the root layout for nulling out the value
// when navigating directly to the base route.
export const to_nav_link_href = (app: Frontend, link: Nav_Link_Item): string => {
	if (
		link.label === 'chats' &&
		app.chats.selected_id_last_non_null &&
		!(page.url.pathname === link.href || page.url.pathname.startsWith(link.href + '/'))
	) {
		return link.href + '/' + app.chats.selected_id_last_non_null;
	} else if (
		link.label === 'prompts' &&
		app.prompts.selected_id_last_non_null &&
		!(page.url.pathname === link.href || page.url.pathname.startsWith(link.href + '/'))
	) {
		return link.href + '/' + app.prompts.selected_id_last_non_null;
	}
	return link.href;
};

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
		group: 'AI',
		items: [
			{label: 'models', href: `${base}/models`, icon: GLYPH_MODEL},
			{label: 'providers', href: `${base}/providers`, icon: GLYPH_PROVIDER},
		],
	},
	{
		group: 'System',
		items: [
			{label: 'about', href: `${base}/about`, icon: zzz_logo},
			{label: 'capabilities', href: `${base}/capabilities`, icon: GLYPH_CAPABILITY},
			{label: 'log', href: `${base}/log`, icon: GLYPH_LOG},
			{label: 'settings', href: `${base}/settings`, icon: GLYPH_SETTINGS},
		],
	},
];
