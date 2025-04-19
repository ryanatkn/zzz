<script lang="ts">
	import {base} from '$app/paths';

	import Nav_Link from '$lib/Nav_Link.svelte';
	import {GLYPH_PROMPT} from '$lib/glyphs.js';
	import Contextmenu_Prompt from '$lib/Contextmenu_Prompt.svelte';
	import type {Prompt} from '$lib/prompt.svelte.js';
	import Glyph from '$lib/Glyph.svelte';

	interface Props {
		prompt: Prompt;
		selected?: boolean | undefined;
	}

	const {prompt, selected}: Props = $props();
</script>

<Contextmenu_Prompt {prompt}>
	<Nav_Link
		href="{base}/prompts/{prompt.id}"
		{selected}
		attrs={{
			class: 'justify_content_space_between',
			style: 'min-height: 0;',
		}}
	>
		<div>
			<Glyph text={GLYPH_PROMPT} attrs={{class: 'mr_xs2'}} />
			<span>{prompt.name}</span>
		</div>
		{#if prompt.bits.length}<small>{prompt.bits.length}</small>{/if}
	</Nav_Link>
</Contextmenu_Prompt>
