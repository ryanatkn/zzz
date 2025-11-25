<script lang="ts">
	import {resolve} from '$app/paths';

	import NavLink from '$lib/NavLink.svelte';
	import {GLYPH_PROMPT} from '$lib/glyphs.js';
	import PromptContextmenu from '$lib/PromptContextmenu.svelte';
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

<PromptContextmenu {prompt}>
	<NavLink
		href={resolve(`/prompts/${prompt.id}`)}
		{selected}
		class="justify_content_space_between"
		style="min-height: 0;"
	>
		<div class="ellipsis">
			<Glyph glyph={GLYPH_PROMPT} class="mr_xs2" />
			<span>{prompt.name}</span>
		</div>
		{#if prompt.parts.length}<small>{prompt.parts.length}</small>{/if}
	</NavLink>
</PromptContextmenu>
