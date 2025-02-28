<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';
	import {Reorderable} from '$lib/reorderable.svelte.js';
	import Bit_Summary from '$lib/Bit_Summary.svelte';

	interface Props {
		prompt: Prompt;
	}

	const {prompt}: Props = $props();

	// Create a reorderable instance
	const reorderable = new Reorderable();

	// Define a shared reorder handler
	const handle_reorder = (from_index: number, to_index: number) => {
		prompt.reorder_bits(from_index, to_index);
	};
</script>

<div class="column">
	<ul
		class="unstyled"
		use:reorderable.list={{
			onreorder: handle_reorder,
		}}
	>
		{#each prompt.bits as bit, i (bit.id)}
			<li class="radius_xs" use:reorderable.item={{index: i}}>
				<Bit_Summary {bit} {prompt} />
			</li>
		{/each}
	</ul>

	<!-- Uncomment to test horizontal layout
	<ul
		class="unstyled row"
		use:reorderable.list={{
			onreorder: handle_reorder,
		}}
	>
		{#each prompt.bits as bit, i (bit.id)}
			<li class="radius_xs" use:reorderable.item={{index: i}}>
				<Bit_Summary {bit} {prompt} />
			</li>
		{/each}
	</ul>
	-->
</div>
