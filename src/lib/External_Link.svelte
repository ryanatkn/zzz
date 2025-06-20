<script lang="ts" module>
	// TODO refactor
	const github_regex = /^https:\/\/(?:[\w-]+\.)*github\.com\//;
	const openai_regex = /^https:\/\/(?:[\w-]+\.)*(chatgpt\.com|openai\.com)\//;
	const anthropic_regex = /^https:\/\/(?:[\w-]+\.)*(claude\.ai|anthropic\.com)\//;
	const google_regex = /^https:\/\/(?:[\w-]+\.)*(google\.com|google\.dev)\//;
</script>

<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';
	import type {Snippet} from 'svelte';
	import {chatgpt_logo, claude_logo, gemini_logo, github_logo} from '@ryanatkn/fuz/logos.js';
	import Svg, {type Svg_Data} from '@ryanatkn/fuz/Svg.svelte';

	import External_Link_Icon from '$lib/External_Link_Icon.svelte';

	// TODO maybe make this `Link` and infer optional prop `external`?

	interface Props {
		href: string;
		/** Set to false to disable external link behavior. */
		open_externally?: boolean | undefined;
		attrs?: SvelteHTMLElements['a'] | undefined;
		icon?: Snippet<[known_logo: Svg_Data | null]> | undefined;
		children?: Snippet | undefined;
	}

	const {href, open_externally = true, attrs, icon, children}: Props = $props();

	const known_logo: Svg_Data | null = $derived(
		github_regex.test(href)
			? github_logo
			: openai_regex.test(href)
				? chatgpt_logo
				: anthropic_regex.test(href)
					? claude_logo
					: google_regex.test(href)
						? gemini_logo
						: null,
	);
</script>

<a
	{...attrs}
	{href}
	target={open_externally ? (attrs?.target ?? '_blank') : attrs?.target}
	rel={open_externally ? (attrs?.rel ?? 'noopener') : attrs?.rel}
	>{#if children}{@render children()}{:else}{href}{/if}<External_Link_Icon
		>{#snippet children(text_icon)}{#if icon}{@render icon(known_logo)}{:else if known_logo}<Svg
					data={known_logo}
					size="var(--font_size_xs)"
					fill="var(--text_color)"
					inline
				/>{:else}{text_icon}{/if}{/snippet}</External_Link_Icon
	></a
>
