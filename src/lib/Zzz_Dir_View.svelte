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

	// TODO BLOCK when server is unavailable, change the content to reflect that (see Socket_Controls for connected status style)

	// Fall back to the context value if not provided
	const zzz_dir = $derived(zzz_dir_prop !== undefined ? zzz_dir_prop : zzz.zzz_dir);
</script>

<div class="flex gap_md align_items_center mb_xl size_lg">
	<Glyph_Icon icon={GLYPH_DIRECTORY} size="var(--size_xl2)" />
	{#if zzz_dir === undefined}
		<div>&nbsp;</div>
	{:else if zzz_dir === null}
		<div class="row">
			<Pending_Animation />
		</div>
	{:else if zzz_dir === ''}
		<div>No server directory configured</div>
	{:else}
		<div>{zzz_dir}</div>
	{/if}
</div>
<p>
	This is the server's filesystem directory, the <code>zzz_dir</code>.
</p>
<p>
	For security reasons, all filesystem operations are confined to this path's parent {#if zzz.zzz_dir_parent}(<small
			class="chip font_mono">{zzz.zzz_dir_parent}</small
		>){/if}
	and the path cannot be modified after the server starts. To configure it set the .env variable
	<code>PUBLIC_ZZZ_DIR</code>.
</p>
