<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';
	import type {Snippet} from 'svelte';
	import {github_logo} from '@ryanatkn/fuz/logos.js';
	import Svg, {type Svg_Data} from '@ryanatkn/fuz/Svg.svelte';

	import External_Link_Icon from '$lib/External_Link_Icon.svelte';

	interface Props {
		href: string;
		open_externally?: boolean | undefined; // Set to false to disable external link behavior
		attrs?: SvelteHTMLElements['a'] | undefined;
		icon?: Snippet<[known_logo: Svg_Data | null]> | undefined;
		children?: Snippet | undefined;
	}

	const {href, open_externally = true, attrs, icon, children}: Props = $props();

	const known_logo: Svg_Data | null = $derived(
		href.startsWith('https://github.com/') ? github_logo : null,
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
					size="var(--size_xs)"
					inline
				/>{:else}{text_icon}{/if}{/snippet}</External_Link_Icon
	></a
>
