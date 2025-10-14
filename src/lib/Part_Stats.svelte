<script lang="ts">
	import type {Part_Union} from '$lib/part.svelte.js';
	import Content_Stats from '$lib/Content_Stats.svelte';

	const {
		part,
	}: {
		part: Part_Union;
	} = $props();

	const token_count = $derived(part.token_count ?? 0);
</script>

<Content_Stats {token_count} />
