<script lang="ts">
	import type {Snippet} from 'svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_ERROR} from '$lib/glyphs.js';

	const {
		glyph = GLYPH_ERROR,
		children,
	}: {
		glyph?: string | null;
		children: Snippet;
	} = $props();
</script>

<span class="color_c_5">
	{#if glyph}
		<Glyph {glyph} />
	{/if}
	{@render children()}
</span>
