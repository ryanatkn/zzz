<script lang="ts">
	import Control_Panel from '$lib/Control_Panel.svelte';

	// TODO display capabilities (like what APIs are available, including remote server, local pglite (could be disconnected, websockets?))
	// TODO display database info/explorer
</script>

<header class="box">
	<h1>System</h1>
</header>
<div class="shadow_inset_top_sm p_lg">
	<Control_Panel />
</div>
