<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';
	import ContentStats from '$lib/ContentStats.svelte';

	const {
		prompt,
	}: {
		prompt: Prompt;
	} = $props();

	const token_count = $derived(prompt.token_count);
</script>

<ContentStats {token_count} />
