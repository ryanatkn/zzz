<script lang="ts">
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import type {Zzz_Dir} from '$lib/diskfile_types.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_DIRECTORY} from '$lib/glyphs.js';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';

	// Props definition
	interface Props {
		zzz_dirs?: Array<Zzz_Dir> | null;
	}

	// Get props with default to context value
	const props: Props = $props();
	const zzz = zzz_context.get();

	// Use prop value if provided, otherwise use context value
	const zzz_dirs = $derived(props.zzz_dirs !== undefined ? props.zzz_dirs : zzz.zzz_dirs);
</script>

<div class="column align_items_start">
	<h2 class="flex align_items_center gap_xs">
		<Glyph_Icon icon={GLYPH_DIRECTORY} /> <span class="ml_xl">directories</span>
	</h2>

	{#if zzz_dirs === null}
		<div class="row">
			<span class="mr_xs2 font_mono">loading</span>
			<Pending_Animation />
		</div>
	{:else if zzz_dirs.length === 0}
		<p>No directories configured</p>
	{:else}
		<ul class="unstyled">
			{#each zzz_dirs as dir}
				<li class="flex gap_xs align_items_center p_xs bg_2 radius_xs mb_xs">
					<Glyph_Icon icon={GLYPH_DIRECTORY} size="xs" />
					<span class="font_mono">{dir}</span>
				</li>
			{/each}
		</ul>
	{/if}
</div>
