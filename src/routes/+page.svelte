<script lang="ts">
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';

	import Zzz_Main from '$lib/Zzz_Main.svelte';
</script>

<Zzz_Main>
	<header class="box">
		<Svg data={zzz_logo} size="var(--icon_size_xl2)" classes="my_xl5" />
	</header>
</Zzz_Main>

<style>
	/* TODO accidentally selected all the links like this, I kind of like it */
	/* TODO construct for this in CSS classes */
	/* TODO something like this but toned down
	a:hover {
		box-shadow: var(--shadow_md) color-mix(in hsl, var(--shadow_color) var(--shadow_alpha_3), transparent); 
	} */
	a:active {
		box-shadow: var(--shadow_inset_top_sm)
			color-mix(in hsl, var(--shadow_color) var(--shadow_alpha_2), transparent);
	}
</style>
