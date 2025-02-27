<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';
	import type {Snippet} from 'svelte';

	import External_Link_Symbol from '$lib/External_Link_Symbol.svelte';

	interface Props {
		href: string;
		open_externally?: boolean; // Set to false to disable external link behavior
		attrs?: SvelteHTMLElements['a'];
		children?: Snippet;
	}

	const {href, open_externally = true, attrs, children}: Props = $props();
</script>

<a
	{...attrs}
	{href}
	target={open_externally ? (attrs?.target ?? '_blank') : attrs?.target}
	rel={open_externally ? (attrs?.rel ?? 'noopener') : attrs?.rel}
>
	{#if children}
		{@render children()}
	{:else}
		{href}
	{/if}<External_Link_Symbol />
</a>
