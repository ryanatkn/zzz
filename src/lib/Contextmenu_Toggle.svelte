<script lang="ts">
	import type {ComponentProps, Snippet} from 'svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import {GLYPH_CHECKMARK} from '$lib/glyphs.js';

	interface Props
		extends Omit_Strict<Partial<ComponentProps<typeof Contextmenu_Entry>>, 'children'> {
		enabled: boolean;
		children?: Snippet<[enabled: boolean]>;
	}

	let {
		enabled = $bindable(),
		icon = icon_default,
		run = () => {
			enabled = !enabled;
		},
		children = children_default,
		...rest
	}: Props = $props();
</script>

<Contextmenu_Entry {...rest} {run} {icon}>
	{@render children(enabled)}
</Contextmenu_Entry>

{#snippet children_default(enabled: boolean)}
	{#if enabled}disable{:else}enable{/if} item
{/snippet}

{#snippet icon_default()}
	<span class:dormant={enabled} class:size_xs={enabled}>{GLYPH_CHECKMARK}</span>
{/snippet}
