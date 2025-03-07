<script lang="ts">
	import {slide} from 'svelte/transition';

	import type {Prompt} from '$lib/prompt.svelte.js';
	import {Reorderable} from '$lib/reorderable.svelte.js';
	import Bit_Summary from '$lib/Bit_Summary.svelte';

	interface Props {
		prompt: Prompt;
	}

	const {prompt}: Props = $props();

	const reorderable = new Reorderable();
	// const reorderable2 = new Reorderable();

	// Define a shared reorder handler
	const handle_reorder = (from_index: number, to_index: number) => {
		prompt.reorder_bits(from_index, to_index);
	};
</script>

<div class="column">
	<ul
		class="unstyled column gap_xs5"
		use:reorderable.list={{
			onreorder: handle_reorder,
		}}
	>
		{#each prompt.bits as bit, i (bit.id)}
			<li class="radius_xs" use:reorderable.item={{index: i}} transition:slide>
				<Bit_Summary {bit} {prompt} />
			</li>
		{/each}
	</ul>

	<!-- Uncomment to test horizontal layout -->
	<!-- <ul
		class="unstyled row"
		use:reorderable2.list={{
			onreorder: handle_reorder,
		}}
	>
		{#each prompt.bits as bit, i (bit.id)}
			<li class="radius_xs" use:reorderable2.item={{index: i}}>
				<Bit_Summary {bit} {prompt} />
			</li>
		{/each}
	</ul> -->
</div>
