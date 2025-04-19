<script lang="ts">
	import type {ComponentProps, Snippet} from 'svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';
	import {DEV} from 'esm-env';

	import {GLYPH_CHECKMARK} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	interface Props
		extends Omit_Strict<Partial<ComponentProps<typeof Contextmenu_Entry>>, 'children'> {
		enabled: boolean;
		label?: string | undefined;
		children?: Snippet<[enabled: boolean]> | undefined;
	}

	let {
		enabled = $bindable(),
		icon = icon_default,
		run = () => {
			enabled = !enabled;
		},
		label = 'item',
		children,
		...rest
	}: Props = $props();

	if (DEV && label && children) throw Error('Cannot provide both label and children');

	const final_children = $derived(children ?? children_default);
</script>

<Contextmenu_Entry {...rest} {run} {icon}>
	{@render final_children(enabled)}
</Contextmenu_Entry>

{#snippet children_default(enabled: boolean)}
	{#if enabled}disable{:else}enable{/if}
	{label}
{/snippet}

{#snippet icon_default()}
	<span class:dormant={enabled} class:size_xs={enabled}><Glyph text={GLYPH_CHECKMARK} /></span>
{/snippet}
