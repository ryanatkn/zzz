<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';

	import type {Part_Union} from '$lib/part.svelte.js';
	import Part_Contextmenu from '$lib/Part_Contextmenu.svelte';

	const {
		part,
		selected,
		onclick,
		compact = true,
		attrs,
	}: {
		part: Part_Union;
		selected?: boolean | undefined;
		onclick?: ((part: Part_Union) => void) | undefined;
		compact?: boolean | undefined;
		attrs?: SvelteHTMLElements['button'] | undefined;
	} = $props();
</script>

<Part_Contextmenu {part}>
	<button
		type="button"
		class="listitem width_100"
		{...attrs}
		class:selected
		class:compact
		onclick={onclick ? () => onclick(part) : undefined}
	>
		<div class="p_xs font_size_sm">
			<span class="mr_xs">{part.type}</span>
			<span class="ellipsis">{part.content_preview}</span>
			{#if part.token_count != null}
				<span class="font_size_xs ml_xs">{part.token_count}</span>
			{/if}
		</div>
	</button>
</Part_Contextmenu>
