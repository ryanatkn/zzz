<script lang="ts">
	import type {Bit_Union} from '$lib/bit.svelte.js';
	import Content_Stats from '$lib/Content_Stats.svelte';

	const {
		bit,
	}: {
		bit: Bit_Union;
	} = $props();

	const token_count = $derived(bit.token_count ?? 0);
</script>

<Content_Stats {token_count} />
