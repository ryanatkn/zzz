<script lang="ts">
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import {base} from '$app/paths';

	import Zzz_Main from '$lib/Zzz_Main.svelte';
	import {hud_context} from '$lib/hud.svelte.js';

	// TODO remove this after fixing
	// class:row
	// class:content
	// class:icon
	// class:title

	hud_context.set(hud);
</script>

<Zzz_Main>
	<header class="box">
		<Svg data={zzz_logo} size="var(--icon_size_xl2)" classes="my_xl5" />
		<p class="mt_xl3">bot control web</p>
		<p class="mt_xl3">work in progress</p>
		<p class="mt_xl3">press <code>`</code> to begin</p>
		<a href="{base}/about" class="size_xl3 px_md radius_0 row h_100">💤</a>
	</header>
</Zzz_Main>

{#snippet hud()}
	<div class="h_100 row justify_content_space_between"></div>
{/snippet}
