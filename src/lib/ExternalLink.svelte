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
	import Svg, {type SvgData} from '@ryanatkn/fuz/Svg.svelte';

	import ExternalLinkIcon from '$lib/ExternalLinkIcon.svelte';

	// TODO maybe make this `Link` and infer optional prop `external`?

	const {
		href,
		open_externally = true,
		icon,
		children,
		...rest
	}: SvelteHTMLElements['a'] & {
		href: string;
		// TODO maybe dont default to external?
		/** Set to false to disable external link behavior. */
		open_externally?: boolean | undefined;
		icon?: Snippet<[known_logo: SvgData | null]> | undefined;
	} = $props();

	const known_logo: SvgData | null = $derived(
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
	{...rest}
	{href}
	target={open_externally ? (rest.target ?? '_blank') : rest.target}
	rel={open_externally ? (rest.rel ?? 'noopener') : rest.rel}
	class:color_i_5={true}
	>{#if children}{@render children()}{:else}{href}{/if}<ExternalLinkIcon
		>{#snippet children(text_icon)}{#if icon}{@render icon(known_logo)}{:else if known_logo}<Svg
					data={known_logo}
					size="var(--font_size_xs)"
					fill="var(--color_i_5)"
					inline
				/>{:else}{text_icon}{/if}{/snippet}</ExternalLinkIcon
	></a
>
