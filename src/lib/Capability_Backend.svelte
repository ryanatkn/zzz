<script lang="ts">
	import {slide} from 'svelte/transition';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {onMount} from 'svelte';

	import {frontend_context} from '$lib/frontend.svelte.js';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_ARROW_RIGHT} from '$lib/glyphs.js';
	import Error_Message from '$lib/Error_Message.svelte';
	import {SERVER_URL} from '$lib/constants.js';
	import Ping_Form from '$lib/Ping_Form.svelte';
	import External_Link from '$lib/External_Link.svelte';

	const app = frontend_context.get();
	const {capabilities} = app;

	onMount(() => {
		void capabilities.init_backend_check();
	});
</script>

<div class="display_flex flex_column">
	<div
		class="w_100 chip flex_1 px_xl plain justify_content_space_between"
		style:padding="0 var(--space_xl) !important"
		style:font-weight="400 !important"
		class:color_b={capabilities.backend.status === 'success'}
		class:color_c={capabilities.backend.status === 'failure'}
		class:color_d={capabilities.backend.status === 'pending'}
		class:color_e={capabilities.backend.status === 'initial'}
	>
		<div class="flex_1 column justify_content_center gap_xs" style:min-height="80px">
			<div class="font_size_xl">
				server {capabilities.backend.status === 'success'
					? 'available'
					: capabilities.backend.status === 'failure'
						? 'unavailable'
						: capabilities.backend.status === 'pending'
							? 'checking'
							: 'not checked'}
				{#if capabilities.backend.status === 'pending'}
					<!-- TODO @many Pending_Animation `inline` prop -->
					<Pending_Animation inline />
				{/if}
			</div>
			<small class="font_family_mono"
				>{SERVER_URL}
				{#if capabilities.latest_ping_time !== null}<span
						><Glyph glyph={GLYPH_ARROW_RIGHT} /> {Math.round(capabilities.latest_ping_time)}ms</span
					>{/if}
			</small>
		</div>
		{#if capabilities.backend.data}
			<div class="column align_items_end font_family_mono">
				<div>{Math.round(capabilities.backend.data.round_trip_time)}ms</div>
			</div>
		{/if}
	</div>

	{#if capabilities.backend.error_message}
		<div transition:slide>
			<Error_Message
				><small class="font_family_mono">{capabilities.backend.error_message}</small></Error_Message
			>
		</div>
	{/if}

	<div class="my_lg">
		<p>
			The Zzz server provides local system access (like to your filesystem), handles API requests to
			AI providers, and enables other capabilities that would otherwise be unavailable to the app
			running in the browser. It's made with <External_Link href="https://hono.dev/"
				>Hono</External_Link
			>, a JS server framework that aligns with web standards, and <External_Link
				href="https://svelte.dev/docs/kit/introduction">SvelteKit</External_Link
			>.
		</p>
	</div>

	<Ping_Form />
</div>
