<script lang="ts">
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import type {Zzz_Dir} from '$lib/diskfile_types.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		zzz_dir?: Zzz_Dir | null | undefined;
	}

	// Get props with default to context value
	const {zzz_dir: zzz_dir_prop}: Props = $props();
	const zzz = zzz_context.get();

	// TODO BLOCK when server is unavailable, change the content to reflect that (see Capabilities_View for connected status style)

	// Fall back to the context value if not provided
	const zzz_dir = $derived(zzz_dir_prop !== undefined ? zzz_dir_prop : zzz.zzz_dir);
</script>

<div class="chip plain color_b flex gap_md align_items_center mb_xl size_xl font_weight_400">
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
	This is the server's filesystem directory, the <code>zzz_dir</code>. It defaults to
	<code>.zzz</code> in the current working directory. To configure it set the .env variable
	<code class="size_sm">PUBLIC_ZZZ_DIR</code>.
</p>
<p>
	For security reasons, all filesystem operations are confined to this path's parent{#if zzz.zzz_dir_parent},
		<small class="chip font_mono">{zzz.zzz_dir_parent}</small>,
	{/if} and the path cannot be modified after the server starts. These restrictions ensure predictability
	when exposing sensitive resources like your local hard drive to web scripts.
</p>
