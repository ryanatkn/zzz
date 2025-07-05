<script lang="ts">
	import type {Snippet} from 'svelte';

	interface Props {
		/**
		 * The percentage value of the progress bar, 0-100.
		 */
		value: number;
		text?: Snippet;
	}

	const {value, text}: Props = $props();

	// TODO a11y
</script>

<div class="display_flex align_items_center gap_sm">
	{#if text}
		{@render text()}
	{:else}
		<small class="w_xl4 text_align_right">{value}%</small>
	{/if}
	<div
		class="flex_1 bg_5 border_radius_xs overflow_hidden"
		style:height="var(--progress_bar_height, 6px)"
	>
		<div class="bg_a_5 h_100" style:width="{value}%"></div>
	</div>
</div>
