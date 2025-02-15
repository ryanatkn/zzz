<script lang="ts">
	import type {Snippet} from 'svelte';
	import {is_editable, swallow} from '@ryanatkn/belt/dom.js';

	import {Zzz, zzz_context} from '$lib/zzz.svelte.js';

	/*

	Sets `zzz` in context.

	*/

	interface Props {
		zzz: Zzz;
		children: Snippet<[zzz: Zzz]>;
	}

	const {zzz, children}: Props = $props();

	zzz_context.set(zzz);
</script>

<svelte:window
	onkeydown={(e) => {
		if (e.key === '`' && !is_editable(e.target)) {
			zzz.data.toggle_main_menu();
			swallow(e);
		}
	}}
/>

{@render children(zzz)}
