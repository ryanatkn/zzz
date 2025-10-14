<script lang="ts">
	import {slide} from 'svelte/transition';
	import type {Snippet} from 'svelte';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import {DEV} from 'esm-env';

	import {Reorderable, type Reorderable_Options} from '$lib/reorderable.svelte.js';
	import Part_Summary from '$lib/Part_Summary.svelte';
	import type {Part_Union} from '$lib/part.svelte.js';
	import type {Prompt} from '$lib/prompt.svelte.js';

	const {
		parts,
		prompt,
		onreorder,
		reorderable_options,
		item_attrs,
		attrs,
		empty = empty_default,
	}: {
		parts: Array<Part_Union>;
		prompt?: Prompt | undefined;
		onreorder?: ((from_index: number, to_index: number) => void) | undefined;
		reorderable_options?: Reorderable_Options | undefined;
		item_attrs?: SvelteHTMLElements['li'] | undefined;
		attrs?: SvelteHTMLElements['ul'] | undefined;
		empty?: Snippet | undefined;
	} = $props();

	const reorderable = $derived(onreorder ? new Reorderable(reorderable_options) : null);

	if (DEV && !onreorder && !!reorderable_options) {
		console.error('`reorderable_options` provided to `Part_List` without `onreorder`');
	}
</script>

<!-- TODO create part button -->

<!-- TODO clean this up with attachments -->

{#if parts.length === 0}
	{@render empty()}
{:else if reorderable && onreorder}
	<ul
		{...attrs}
		class="unstyled column gap_xs5 {attrs?.class}"
		{@attach reorderable.list({onreorder})}
	>
		{#each parts as part, i (part.id)}
			<li
				{...item_attrs}
				class="border_radius_xs {item_attrs?.class}"
				{@attach reorderable.item({index: i})}
				transition:slide
			>
				<Part_Summary {part} {prompt} />
			</li>
		{/each}
	</ul>
{:else}
	<ul {...attrs} class="unstyled column gap_xs5 {attrs?.class}">
		{#each parts as part (part.id)}
			<li {...item_attrs} class="border_radius_xs {item_attrs?.class}" transition:slide>
				<Part_Summary {part} {prompt} />
			</li>
		{/each}
	</ul>
{/if}

{#snippet empty_default()}
	<small class="font_family_mono">[no parts yet]</small>
{/snippet}
