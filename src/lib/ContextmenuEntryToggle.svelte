<script lang="ts">
	import type {ComponentProps, Snippet} from 'svelte';
	import ContextmenuEntry from '@ryanatkn/fuz/ContextmenuEntry.svelte';
	import type {OmitStrict} from '@ryanatkn/belt/types.js';
	import {DEV} from 'esm-env';

	import {GLYPH_CHECKMARK} from './glyphs.js';
	import Glyph from './Glyph.svelte';

	let {
		enabled = $bindable(),
		icon = icon_default,
		run = () => {
			enabled = !enabled;
		},
		label = 'item',
		children,
		...rest
	}: OmitStrict<Partial<ComponentProps<typeof ContextmenuEntry>>, 'children'> & {
		enabled: boolean;
		label?: string | undefined;
		children?: Snippet<[enabled: boolean]> | undefined;
	} = $props();

	if (DEV && label && children) throw new Error('cannot provide both label and children');

	const final_children = $derived(children ?? children_default);
</script>

<ContextmenuEntry {...rest} {run} {icon}>
	{@render final_children(enabled)}
</ContextmenuEntry>

{#snippet children_default(enabled: boolean)}
	{#if enabled}disable{:else}enable{/if}
	{label}
{/snippet}

{#snippet icon_default()}
	<span class:dormant={enabled} class:font_size_xs={enabled}><Glyph glyph={GLYPH_CHECKMARK} /></span
	>
{/snippet}
