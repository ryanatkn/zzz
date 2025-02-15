<script lang="ts">
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import {DEV} from 'esm-env';

	import Zzz_Main from '$lib/Zzz_Main.svelte';
	import {hud_context} from '$lib/hud.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	// TODO remove this after fixing
	// class:row
	// class:content
	// class:icon
	// class:title

	const zzz = zzz_context.get();

	hud_context.set(hud);
</script>

<Zzz_Main>
	<footer class="box py_xl9">
		<Svg data={zzz_logo} size="var(--icon_size_xl2)" classes="my_xl5" />
		<p class="mt_xl3">bot control web</p>
		<p class="mt_xl3">work in progress</p>
		{#if !DEV}
			<p>
				At the moment, Zzz only functions when run locally on your dev machine. The goal is to make
				it available in all contexts, but you gotta start somewhere.
			</p>
		{/if}
	</footer>
</Zzz_Main>

{#snippet hud()}
	<div class="h_100 row justify_content_end">
		<button type="button" class="radius_0 plain" onclick={() => (zzz.data.show_main_menu = true)}
			>☰</button
		>
	</div>
{/snippet}
