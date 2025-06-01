<script lang="ts">
	import type {Snippet} from 'svelte';

	import {Zzz_App, zzz_context} from '$lib/zzz.svelte.js';
	import Dashboard from '$lib/Dashboard.svelte';
	import Main_Dialog from '$lib/Main_Dialog.svelte';

	/*

	Sets `app` in context.

	*/

	interface Props {
		app: Zzz_App;
		children: Snippet<[zzz: Zzz_App]>;
	}

	const {app, children}: Props = $props();

	zzz_context.set(app);
</script>

<Main_Dialog />
<!-- TODO user-defined pages should be able to control the full page at runtime -->
<Dashboard>
	<div class="h_100 overflow_auto">
		{@render children(app)}
	</div>
</Dashboard>
