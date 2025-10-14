<script lang="ts">
	import type {Snippet} from 'svelte';
	import Themed from '@ryanatkn/fuz/Themed.svelte';
	import Contextmenu_Root from '@ryanatkn/fuz/Contextmenu_Root.svelte';

	import {Frontend, frontend_context} from '$lib/frontend.svelte.js';
	import Dashboard from '$lib/Dashboard.svelte';
	import Main_Dialog from '$lib/Main_Dialog.svelte';

	// TODO maybe just make this `Zzz`?

	/*

	Sets `app` in context.

	*/

	const {
		app,
		children,
	}: {
		app: Frontend;
		children: Snippet<[zzz: Frontend]>;
	} = $props();

	frontend_context.set(app);
</script>

<Themed>
	<Contextmenu_Root>
		<Main_Dialog />
		<!-- TODO user-defined pages should be able to control the full page at runtime -->
		<Dashboard>
			<div class="height_100 overflow_auto">
				{@render children(app)}
			</div>
		</Dashboard>
	</Contextmenu_Root>
</Themed>
