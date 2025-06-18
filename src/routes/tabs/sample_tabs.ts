import {create_uuid, get_datetime_now} from '$lib/zod_helpers.js';
import type {Browser_Tab_Json} from '$routes/tabs/browser_tab.svelte.js';

// Fake site content for embedded HTML tabs
export const fake_sites = {
	future: {
		title: 'Zzz in the future',
		url: 'https://www.zzz.software/future',
		content: `
			<article style="padding: 10px;">
				<header>
					<h1>Zzz in the future</h1>
				</header>
				<section style="width: 300px">
					<p>Zzz is an ambitious concept and I don't know what could come of it. Maybe it remains a portfolio item that helps me get a job building similar things, or maybe it'll get traction with some enthusiasts to validate my continued work. I'm applying to some grants, so that should be helpful feedback one way or the other.</p>
					<p>I can say for certain I won't raise VC or change it from being a permissively licensed open source project. I'm sympathetic to copyleft but I feel this is the better way, for me, to make better software that's useful to more people.</p>
					<p>In terms of roadmap, I plan to work on the browser functionality sometime after the sites proof of concept with basic IDE/CMS features, so it'll be a while.</p>
					<p>Head over to <a href="https://github.com/ryanatkn/zzz" target="_blank" rel="noopener">GitHub</a> to learn more.</p>
				</section>
			</article>
		`,
	},
	new_tab: {
		title: 'new tab',
		url: 'about:newtab',
		content: `
			<div style="padding: 20px; font-family: system-ui;">
				<h1>new tab</h1>
				<ul>
					<li><a href="https://www.zzz.software/about" target="_blank" rel="noopener">about Zzz</a></li>
					<li><a href="https://github.com/ryanatkn/zzz" target="_blank" rel="noopener">source code</a></li>
				</ul>
			</div>
		`,
	},
};

// Sample tabs for browser initialization
const created = get_datetime_now();
export const sample_tabs: Array<Browser_Tab_Json> = [
	{
		id: create_uuid(),
		title: 'Zzz is a browser',
		url: 'https://www.zzz.software/tabs',
		type: 'raw',
		selected: true,
		refresh_counter: 0,
		created,
		updated: created,
	},
	{
		id: create_uuid(),
		title: fake_sites.future.title,
		selected: false,
		url: fake_sites.future.url,
		type: 'embedded_html',
		content: fake_sites.future.content,
		refresh_counter: 0,
		created,
		updated: created,
	},
	{
		id: create_uuid(),
		title: 'Moss',
		selected: false,
		url: 'https://moss.ryanatkn.com/',
		type: 'external_url',
		refresh_counter: 0,
		created,
		updated: created,
	},
	{
		id: create_uuid(),
		title: 'Fuz',
		selected: false,
		url: 'https://fuz.dev/',
		type: 'external_url',
		refresh_counter: 0,
		created,
		updated: created,
	},
];
