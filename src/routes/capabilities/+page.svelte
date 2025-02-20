<script lang="ts">
	import {DEV} from 'esm-env';

	import {SYMBOL_CAPABILITIES} from '$lib/constants.js';

	// TODO display capabilities (like what APIs are available, including remote server (off when deployed statically), local pglite (could be disconnected, websockets?))
	// TODO display database info/explorer
</script>

<div class="p_lg">
	<header>
		<h1>{SYMBOL_CAPABILITIES} System capabilities</h1>
	</header>
	<section>
		<h2>Todo</h2>
		<ul>
			<li>Node server</li>
			<ul>
				<li>websocket connection</li>
			</ul>
			<li>Providers (API keys)</li>
		</ul>
	</section>
	<section class="width_sm">
		<p>
			DEV mode: {DEV.toString()}
		</p>
	</section>
</div>
