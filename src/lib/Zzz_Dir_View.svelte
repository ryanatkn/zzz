<script lang="ts">
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import type {Zzz_Dir} from '$lib/diskfile_types.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_DIRECTORY} from '$lib/glyphs.js';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';

	interface Props {
		zzz_dir?: Zzz_Dir | null | undefined;
	}

	// Get props with default to context value
	const {zzz_dir: zzz_dir_prop}: Props = $props();
	const zzz = zzz_context.get();

	// Fall back to the context value if not provided
	const zzz_dir = $derived(zzz_dir_prop !== undefined ? zzz_dir_prop : zzz.zzz_dir);
</script>

<div class="column align_items_start">
	<h2 class="flex align_items_center gap_xs">
		<Glyph_Icon icon={GLYPH_DIRECTORY} /> <span class="ml_xl">directories</span>
	</h2>

	{#if zzz_dir === undefined}
		<div>&nbsp;</div>
	{:else if zzz_dir === null}
		<div class="row">
			<span class="mr_xs2 font_mono">loading</span>
			<Pending_Animation />
		</div>
	{:else if zzz_dir === ''}
		<div>No server directory configured</div>
	{:else}
		<div class="flex gap_xs align_items_center p_xs bg_2 radius_xs mb_xs">
			<Glyph_Icon icon={GLYPH_DIRECTORY} size="xs" />
			<span class="font_mono">{zzz_dir}</span>
		</div>
	{/if}
</div>
