<script lang="ts">
	import {SYMBOL_SETTINGS} from '$lib/constants.js';
	import Control_Panel from '$lib/Control_Panel.svelte';
	import Settings from '$lib/Settings.svelte';

	// TODO display capabilities (like what APIs are available, including remote server (off when deployed statically), local pglite (could be disconnected, websockets?))
	// TODO display database info/explorer
</script>

<div class="p_lg">
	<header>
		<h1>{SYMBOL_SETTINGS} System settings</h1>
	</header>
	<Control_Panel />
	<section class="width_sm">
		<Settings />
	</section>
</div>
