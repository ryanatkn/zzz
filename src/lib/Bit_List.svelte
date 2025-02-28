<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';
	import {reorderable_list, reorderable_item} from '$lib/reorderable.svelte.js';
	import Bit_Summary from '$lib/Bit_Summary.svelte';

	interface Props {
		prompt: Prompt;
	}

	const {prompt}: Props = $props();
</script>

<div class="column">
	<ul
		class="unstyled"
		use:reorderable_list={{
			onreorder: (from_index, to_index) => {
				prompt.reorder_bits(from_index, to_index);
			},
		}}
	>
		{#each prompt.bits as bit, i (bit.id)}
			<li class="radius_xs" use:reorderable_item={{index: i}}>
				<Bit_Summary {bit} {prompt} />
			</li>
		{/each}
	</ul>
	<!-- TODO delete -->
	<ul
		class="unstyled row"
		use:reorderable_list={{
			onreorder: (from_index, to_index) => {
				prompt.reorder_bits(from_index, to_index);
			},
		}}
	>
		{#each prompt.bits as bit, i (bit.id)}
			<li class="radius_xs" use:reorderable_item={{index: i}}>
				<Bit_Summary {bit} {prompt} />
			</li>
		{/each}
	</ul>
</div>
