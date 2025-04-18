<script lang="ts">
	import type {Snippet} from 'svelte';

	import {GLYPH_EXTERNAL_LINK} from '$lib/glyphs.js';

	interface Props {
		children?: Snippet<[text_icon: string]>;
	}

	const {children}: Props = $props();
</script>

<sup class="size_xs font_mono"
	>[{#if children}{@render children(GLYPH_EXTERNAL_LINK)}{:else}{GLYPH_EXTERNAL_LINK}{/if}]</sup
>
