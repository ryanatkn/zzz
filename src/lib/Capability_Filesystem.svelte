<script lang="ts">
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import type {Zzz_Dir} from '$lib/diskfile_types.js';
	import {frontend_context} from '$lib/frontend.svelte.js';

	interface Props {
		zzz_dir?: Zzz_Dir | null | undefined;
	}

	// Get props with default to context value
	const {zzz_dir: zzz_dir_prop}: Props = $props();

	const app = frontend_context.get();
	const {capabilities} = app;

	// Fall back to the context value if not provided
	const zzz_dir = $derived(zzz_dir_prop !== undefined ? zzz_dir_prop : app.zzz_cache_dir);
</script>

<div
	class="chip plain flex_1 font_size_xl px_xl flex_column mb_xl"
	style:display="display_flex !important"
	style:align-items="flex-start !important"
	style:font-weight="400 !important"
	class:color_b={capabilities.filesystem.status === 'success'}
	class:color_c={capabilities.filesystem.status === 'failure'}
	class:color_d={capabilities.filesystem.status === 'pending'}
	class:color_e={capabilities.filesystem.status === 'initial'}
>
	<div class="column justify_content_center gap_xs pl_md" style:min-height="80px">
		<div class="font_size_xl">
			filesystem {capabilities.filesystem.status === 'success'
				? 'available'
				: capabilities.filesystem.status === 'failure'
					? 'unavailable'
					: capabilities.filesystem.status === 'pending'
						? 'loading'
						: 'not initialized'}
			{#if capabilities.filesystem.status === 'pending'}
				<Pending_Animation inline />
			{/if}
		</div>
		<small class="font_family_mono">
			{#if zzz_dir === undefined || zzz_dir === null}
				&nbsp;
			{:else if zzz_dir === ''}
				No backend directory configured
			{:else}
				{zzz_dir}
			{/if}
		</small>
	</div>
</div>

<p>
	This is the backend's filesystem directory, the <code>zzz_dir</code>. It defaults to
	<code>.zzz</code> in the backend's current working directory. To configure it set the .env
	variable
	<code class="font_size_sm">PUBLIC_ZZZ_DIR</code>.
</p>
<p>
	For security reasons, all filesystem operations are confined to this path's parent directory,
	<small class="chip font_family_mono">{app.zzz_dir || '[no zzz dir configured]'}</small>, and the
	path cannot be modified after the backend starts. These restrictions may be loosened in the
	future, but they help ensure predictability when exposing sensitive resources like your local hard
	drive to web scripts.
</p>
