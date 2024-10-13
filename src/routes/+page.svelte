<script lang="ts">
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import {base} from '$app/paths';

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
	<header class="box">
		<Svg data={zzz_logo} size="var(--icon_size_xl2)" classes="my_xl5" />
		<p class="mt_xl3">bot control hq</p>
		<p class="mt_xl3">work in progress</p>
		<p class="size_xl3">💤</p>
	</header>
</Zzz_Main>

{#snippet hud()}
	<div class="h_100 row justify_content_space_between">
		<button type="button" class="radius_0 plain" onclick={() => (zzz.data.show_main_menu = true)}
			>menu</button
		>
		<a href="{base}/about" class="px_md radius_0 row h_100"
			>about <Svg data={zzz_logo} size="var(--icon_size_sm)" classes="ml_sm" /></a
		>
	</div>
{/snippet}
