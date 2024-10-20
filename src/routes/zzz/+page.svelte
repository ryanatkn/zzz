<script lang="ts">
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import {base} from '$app/paths';

	import Control_Panel from '$lib/Control_Panel.svelte';
</script>

<header class="box">
	<a href="{base}/"><Svg data={zzz_logo} size="var(--icon_size_xl2)" classes="my_xl5" /></a>
</header>
<div class="flex shadow_inset_top_sm p_lg">
	<Control_Panel />
</div>
