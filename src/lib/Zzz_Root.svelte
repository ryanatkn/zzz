<script lang="ts">
	import type {Snippet} from 'svelte';
	import {swallow} from '@ryanatkn/belt/dom.js';

	import {Zzz, zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		zzz: Zzz;
		children: Snippet<[zzz: Zzz]>;
	}

	const {zzz = new Zzz(), children}: Props = $props();

	zzz_context.set(zzz);
</script>

<svelte:window
	onkeydown={(e) => {
		if (e.key === '`') {
			zzz.data.show_main_menu = !zzz.data.show_main_menu;
			swallow(e);
		}
	}}
/>

{@render children(zzz)}
