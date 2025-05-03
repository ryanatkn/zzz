<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';

	import type {Bit_Type} from '$lib/bit.svelte.js';
	import Contextmenu_Bit from '$lib/Contextmenu_Bit.svelte';

	interface Props {
		bit: Bit_Type;
		selected?: boolean | undefined;
		onclick?: ((bit: Bit_Type) => void) | undefined;
		compact?: boolean | undefined;
		attrs?: SvelteHTMLElements['button'] | undefined;
	}

	const {bit, selected, onclick, compact = true, attrs}: Props = $props();
</script>

<Contextmenu_Bit {bit}>
	<button
		type="button"
		class="listitem w_100"
		{...attrs}
		class:selected
		class:compact
		onclick={onclick ? () => onclick(bit) : undefined}
	>
		<div class="p_xs font_size_sm">
			<span class="mr_xs">{bit.type}</span>
			<span class="ellipsis">{bit.content_preview}</span>
			{#if bit.token_count != null}
				<span class="font_size_xs ml_xs">{bit.token_count}</span>
			{/if}
		</div>
	</button>
</Contextmenu_Bit>
