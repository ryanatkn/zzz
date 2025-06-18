<script lang="ts">
	import type {Snippet} from 'svelte';

	import {Frontend, zzz_context} from '$lib/frontend.svelte.js';
	import Dashboard from '$lib/Dashboard.svelte';
	import Main_Dialog from '$lib/Main_Dialog.svelte';

	// TODO maybe just make this `Zzz`?

	/*

	Sets `app` in context.

	*/

	interface Props {
		app: Frontend;
		children: Snippet<[zzz: Frontend]>;
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
