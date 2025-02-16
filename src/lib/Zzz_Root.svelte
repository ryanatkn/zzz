<script lang="ts">
	import type {Snippet} from 'svelte';
	import {is_editable, swallow} from '@ryanatkn/belt/dom.js';

	import {Zzz, zzz_context} from '$lib/zzz.svelte.js';
	import Hud_Root from '$lib/Hud_Root.svelte';
	import Dashboard from '$lib/Dashboard.svelte';
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

<Hud_Root>
	<!-- TODO pages should be able to control the full page -->
	<Dashboard>
		<main>
			{@render children(zzz)}
		</main>
	</Dashboard>
</Hud_Root>

{#snippet hud_default()}
	<div class="h_100 row justify_content_end">
		<button type="button" class="radius_0 plain" onclick={() => (zzz.data.show_main_menu = true)}
			>☰</button
		>
	</div>
{/snippet}
