<script lang="ts">
	import {slide} from 'svelte/transition';

	import type {Tape} from '$lib/tape.svelte.js';
	import Strip_Listitem from '$lib/Strip_Listitem.svelte';
	import {Scrollable} from '$lib/scrollable.svelte.js';
	import type {SvelteHTMLElements} from 'svelte/elements';

	interface Props {
		tape: Tape;
		attrs?: SvelteHTMLElements['div'] | undefined;
	}

	const {tape, attrs}: Props = $props();

	const scrollable = new Scrollable();

	const strips = $derived(Array.from(tape.strips.by_id.values()));
</script>

<div {...attrs} class="strip_list {attrs?.class}" use:scrollable.container use:scrollable.target>
	<ul class="unstyled">
		{#each strips as strip (strip.id)}
			<li transition:slide>
				<Strip_Listitem {strip} />
			</li>
		{/each}
	</ul>
</div>

<style>
	.strip_list {
		display: flex;
		flex-direction: column-reverse; /* makes scrolling start at the bottom */
		overflow: auto;
		scrollbar-width: thin;
		flex: 1;
		border-radius: var(--radius_xs2);
	}
</style>
