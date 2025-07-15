<script lang="ts">
	import {slide} from 'svelte/transition';
	import type {Snippet} from 'svelte';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import {DEV} from 'esm-env';

	import {Reorderable, type Reorderable_Options} from '$lib/reorderable.svelte.js';
	import Bit_Summary from '$lib/Bit_Summary.svelte';
	import type {Bit_Union} from '$lib/bit.svelte.js';
	import type {Prompt} from '$lib/prompt.svelte.js';

	const {
		bits,
		prompt,
		onreorder,
		reorderable_options,
		item_attrs,
		attrs,
		empty = empty_default,
	}: {
		bits: Array<Bit_Union>;
		prompt?: Prompt | undefined;
		onreorder?: ((from_index: number, to_index: number) => void) | undefined;
		reorderable_options?: Reorderable_Options | undefined;
		item_attrs?: SvelteHTMLElements['li'] | undefined;
		attrs?: SvelteHTMLElements['ul'] | undefined;
		empty?: Snippet | undefined;
	} = $props();

	const reorderable = $derived(onreorder ? new Reorderable(reorderable_options) : null);

	if (DEV && !onreorder && !!reorderable_options) {
		console.error('`reorderable_options` provided to `Bit_List` without `onreorder`');
	}
</script>

<!-- TODO create bit button -->

<!-- TODO clean this up with attachments -->

{#if bits.length === 0}
	{@render empty()}
{:else if reorderable && onreorder}
	<ul
		{...attrs}
		class="unstyled column gap_xs5 {attrs?.class}"
		{@attach reorderable.list({onreorder})}
	>
		{#each bits as bit, i (bit.id)}
			<li
				{...item_attrs}
				class="border_radius_xs {item_attrs?.class}"
				{@attach reorderable.item({index: i})}
				transition:slide
			>
				<Bit_Summary {bit} {prompt} />
			</li>
		{/each}
	</ul>
{:else}
	<ul {...attrs} class="unstyled column gap_xs5 {attrs?.class}">
		{#each bits as bit (bit.id)}
			<li {...item_attrs} class="border_radius_xs {item_attrs?.class}" transition:slide>
				<Bit_Summary {bit} {prompt} />
			</li>
		{/each}
	</ul>
{/if}

{#snippet empty_default()}
	<small class="font_family_mono">[no bits yet]</small>
{/snippet}
