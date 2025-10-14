<script lang="ts">
	import type {Snippet} from 'svelte';

	import {GLYPH_EXTERNAL_LINK} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	const {
		children,
	}: {
		children?: Snippet<[text_icon: string]>;
	} = $props();
</script>

<sup class="font_size_xs font_family_mono white_space_nowrap"
	>[{#if children}{@render children(GLYPH_EXTERNAL_LINK)}{:else}<Glyph
			glyph={GLYPH_EXTERNAL_LINK}
		/>{/if}]</sup
>
