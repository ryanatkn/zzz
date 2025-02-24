<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';
	import Reorderable_List from '$lib/Reorderable_List.svelte';
	import Bit_Summary from '$lib/Bit_Summary.svelte';

	interface Props {
		prompt: Prompt;
	}

	const {prompt}: Props = $props();
</script>

<div class="column">
	<Reorderable_List items={prompt.bits}>
		{#snippet children(bit, dragging, dragging_any)}
			<div
				class="item_wrapper radius_xs"
				class:dragging
				class:dragging_any
				class:dragging_other={dragging_any && !dragging}
			>
				<Bit_Summary {bit} {prompt} />
			</div>
		{/snippet}
	</Reorderable_List>
</div>

<style>
	/* TODO hacky way to style this */
	.item_wrapper {
		border: 1px solid transparent;
	}
	.item_wrapper:hover:not(.dragging_other) {
		border-color: var(--border_color_2);
	}
	.item_wrapper:active:not(.dragging_other) {
		border-color: var(--border_color_4);
	}
	.item_wrapper.dragging:not(.dragging_other) {
		border-color: var(--border_color_5);
	}
</style>
