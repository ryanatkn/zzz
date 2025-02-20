<script lang="ts">
	import type {Snippet} from 'svelte';
	import {is_editable, swallow} from '@ryanatkn/belt/dom.js';

	import {Zzz, zzz_context} from '$lib/zzz.svelte.js';
	import Dashboard from '$lib/Dashboard.svelte';
	import Main_Dialog from '$lib/Main_Dialog.svelte';
	import {hud_context} from '$lib/hud.svelte.js';

	/*

	Sets `zzz` in context.

	*/

	interface Props {
		zzz: Zzz;
		hud?: Snippet;
		children: Snippet<[zzz: Zzz]>;
	}

	const {zzz, hud = hud_default, children}: Props = $props();

	zzz_context.set(zzz);

	hud_context.set(hud);
</script>

<svelte:window
	onkeydown={(e) => {
		if (e.key === '`' && !is_editable(e.target)) {
			zzz.data.toggle_main_menu();
			swallow(e);
		}
	}}
/>

<Main_Dialog />
<!-- TODO user-defined pages should be able to control the full page at runtime -->
<Dashboard>
	<main class="h_100 overflow_auto">
		{@render children(zzz)}
	</main>
</Dashboard>

{#snippet hud_default()}{/snippet}
