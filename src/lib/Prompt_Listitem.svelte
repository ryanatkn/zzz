<script lang="ts">
	import {base} from '$app/paths';

	import Nav_Link from '$lib/Nav_Link.svelte';
	import {GLYPH_PROMPT} from '$lib/glyphs.js';
	import Prompt_Contextmenu from '$lib/Prompt_Contextmenu.svelte';
	import type {Prompt} from '$lib/prompt.svelte.js';
	import Glyph from '$lib/Glyph.svelte';

	const {
		prompt,
		selected,
	}: {
		prompt: Prompt;
		selected?: boolean | undefined;
	} = $props();
</script>

<Prompt_Contextmenu {prompt}>
	<Nav_Link
		href="{base}/prompts/{prompt.id}"
		{selected}
		class="justify_content_space_between"
		style="min-height: 0;"
	>
		<div class="ellipsis">
			<Glyph glyph={GLYPH_PROMPT} class="mr_xs2" />
			<span>{prompt.name}</span>
		</div>
		{#if prompt.bits.length}<small>{prompt.bits.length}</small>{/if}
	</Nav_Link>
</Prompt_Contextmenu>
