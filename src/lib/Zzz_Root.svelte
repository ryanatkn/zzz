<script lang="ts">
	import type {Snippet} from 'svelte';

	import {Zzz, zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		zzz: Zzz;
		children: Snippet<[zzz: Zzz]>;
	}

	const {zzz, children}: Props = $props();

	zzz_context.set(zzz);
</script>

{@render children(zzz)}
