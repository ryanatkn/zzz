<script lang="ts">
	import PendingAnimation from '@ryanatkn/fuz/PendingAnimation.svelte';

	import {frontend_context} from './frontend.svelte.js';

	const app = frontend_context.get();
	const {capabilities} = app;

	const zzz_cache_dir = $derived(app.zzz_cache_dir);
</script>

<div
	class="chip plain flex_1 font_size_xl px_xl flex_direction_column mb_xl width_upto_sm"
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
				<PendingAnimation inline />
			{/if}
		</div>
		<small class="font_family_mono">
			{#if zzz_cache_dir === undefined || zzz_cache_dir === null}
				&nbsp;
			{:else if zzz_cache_dir === ''}
				no backend directory configured
			{:else}
				{zzz_cache_dir}
			{/if}
		</small>
	</div>
</div>

<p>
	This is the backend's filesystem directory. For security reasons, filesystem operations are scoped
	to this directory and symlinks are not followed. Defaults to <code>.zzz</code> in the backend's
	current working directory. To configure it set the .env variable
	<code class="font_size_sm">PUBLIC_ZZZ_CACHE_DIR</code>. Configure at your own risk.
</p>
