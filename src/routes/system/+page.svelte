<script lang="ts">
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import {base} from '$app/paths';

	import Control_Panel from '$lib/Control_Panel.svelte';

	// TODO display capabilities (like what APIs are available, including remote server, local pglite (could be disconnected, websockets?))
	// TODO display database info/explorer
</script>

<header class="box">
	<a href="{base}/"><Svg data={zzz_logo} size="var(--icon_size_xl2)" classes="my_xl5" /></a>
</header>
<div class="shadow_inset_top_sm p_lg">
	<h1>System</h1>
	<Control_Panel />
</div>
