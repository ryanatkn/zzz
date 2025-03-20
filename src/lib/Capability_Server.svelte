<script lang="ts">
	import {slide} from 'svelte/transition';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {onMount} from 'svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {GLYPH_ARROW_RIGHT, GLYPH_CONNECT, GLYPH_REFRESH, GLYPH_RESET} from '$lib/glyphs.js';
	import Error_Message from '$lib/Error_Message.svelte';
	import {SERVER_URL} from '$lib/constants.js';
	import Ping_Form from '$lib/Ping_Form.svelte';

	const zzz = zzz_context.get();
	const {capabilities} = zzz;

	// Initial load when component mounts
	onMount(() => {
		void capabilities.init_server_check();
	});
</script>

<div class="flex flex_column gap_sm">
	<div
		class="w_100 chip flex_1 px_xl plain justify_content_space_between"
		style:font-weight="400 !important"
		style:padding="0 var(--space_xl) !important"
		class:color_b={capabilities.server.status === 'success'}
		class:color_c={capabilities.server.status === 'failure'}
		class:color_d={capabilities.server.status === 'pending'}
		class:color_e={capabilities.server.status === 'initial'}
	>
		<div class="flex_1 column justify_content_center gap_xs" style:min-height="80px">
			<div class="size_xl">
				server {capabilities.server.status === 'success'
					? 'available'
					: capabilities.server.status === 'failure'
						? 'unavailable'
						: capabilities.server.status === 'pending'
							? 'checking'
							: 'not checked'}
				{#if capabilities.server.status === 'pending'}
					<!-- TODO @many Pending_Animation `inline` prop -->
					<Pending_Animation attrs={{style: 'display: inline-flex !important'}} />
				{/if}
			</div>
			<small class="font_mono"
				>{SERVER_URL}/api/ping
				{#if capabilities.server.data}<span
						>{GLYPH_ARROW_RIGHT} {capabilities.server.data.round_trip_time}ms</span
					>{/if}
			</small>
		</div>
		{#if capabilities.server.data}
			<div class="column align_items_end font_mono">
				<div>{capabilities.server.data.name}</div>
				<small>v{capabilities.server.data.version}</small>
			</div>
		{/if}
	</div>

	{#if capabilities.server.error_message}
		<div transition:slide>
			<Error_Message
				><small class="font_mono">{capabilities.server.error_message}</small></Error_Message
			>
		</div>
	{/if}

	<div class="flex justify_content_space_between gap_md">
		<button
			type="button"
			class="flex_1 justify_content_start"
			disabled={capabilities.server.status === 'pending'}
			onclick={() => capabilities.check_server()}
		>
			<Glyph_Icon
				icon={capabilities.server.status === 'success' ? GLYPH_REFRESH : GLYPH_CONNECT}
				size="var(--size_xl)"
			/>
			<span class="size_lg font_weight_400 ml_md">
				{#if capabilities.server.status === 'pending'}
					<div class="inline_flex align_items_end">
						checking <div class="relative"><Pending_Animation /></div>
					</div>
				{:else if capabilities.server.status === 'success'}
					refresh
				{:else}
					check connection
				{/if}
			</span>
		</button>
		<button
			type="button"
			class="flex_1 justify_content_start"
			disabled={capabilities.server.status === 'initial'}
			onclick={() => capabilities.reset_server()}
		>
			<Glyph_Icon icon={GLYPH_RESET} size="var(--size_xl)" />
			<span class="size_lg font_weight_400 ml_md"> reset </span>
		</button>
	</div>

	<div class="my_lg">
		<p>
			The Zzz server provides file system access, handles API requests to AI providers, and
			maintains your workspaces. A local server is required for many features.
		</p>
	</div>

	<Ping_Form />
</div>
