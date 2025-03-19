<script lang="ts">
	import {slide} from 'svelte/transition';
	import type {Snippet} from 'svelte';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import {DEV} from 'esm-env';

	import {Reorderable, type Reorderable_Options} from '$lib/reorderable.svelte.js';
	import Bit_Summary from '$lib/Bit_Summary.svelte';
	import type {Bit_Type} from '$lib/bit.svelte.js';
	import type {Prompt} from '$lib/prompt.svelte.js';

	interface Props {
		bits: Array<Bit_Type>;
		prompt?: Prompt;
		onreorder?: (from_index: number, to_index: number) => void;
		reorderable_options?: Reorderable_Options;
		item_attrs?: SvelteHTMLElements['li'];
		attrs?: SvelteHTMLElements['ul'];
		empty?: Snippet;
	}

	const {
		bits,
		prompt,
		onreorder,
		reorderable_options,
		item_attrs,
		attrs,
		empty = empty_default,
	}: Props = $props();

	const reorderable = $derived(onreorder ? new Reorderable(reorderable_options) : null);

	if (DEV && !onreorder && !!reorderable_options) {
		console.error('`reorderable_options` provided to `Bit_List` without `onreorder`');
	}

	// const reorderable2 = new Reorderable();
</script>

<!-- TODO create bit button -->

<!-- TODO messy until something like this lands bc actions arent conditional
	 and I dont want to make it internally complex with disabled states,
	 there's many entrypoints and reactivity would be tricky - https://github.com/sveltejs/svelte/pull/15000  -->

{#if bits.length === 0}
	{@render empty()}
{:else if reorderable && onreorder}
	<ul {...attrs} class="unstyled column gap_xs5 {attrs?.class}" use:reorderable.list={{onreorder}}>
		{#each bits as bit, i (bit.id)}
			<li
				{...item_attrs}
				class="radius_xs {item_attrs?.class}"
				use:reorderable.item={{index: i}}
				transition:slide
			>
				<Bit_Summary {bit} {prompt} />
			</li>
		{/each}
	</ul>
{:else}
	<ul {...attrs} class="unstyled column gap_xs5 {attrs?.class}">
		{#each bits as bit (bit.id)}
			<li {...item_attrs} class="radius_xs {item_attrs?.class}" transition:slide>
				<Bit_Summary {bit} {prompt} />
			</li>
		{/each}
	</ul>
{/if}

{#snippet empty_default()}
	<small class="font_mono">[no bits yet]</small>
{/snippet}
