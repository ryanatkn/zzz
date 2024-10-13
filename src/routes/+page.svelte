<script lang="ts">
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import {base} from '$app/paths';

	import Zzz_Main from '$lib/Zzz_Main.svelte';
	import {hud_context} from '$lib/Hud.svelte';

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
	</header>
</Zzz_Main>

{#snippet hud()}
	<a href="{base}/about" class="size_xl3 justify_self_end">?</a>
{/snippet}
