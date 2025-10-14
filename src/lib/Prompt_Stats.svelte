<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';
	import Content_Stats from '$lib/Content_Stats.svelte';

	const {
		prompt,
	}: {
		prompt: Prompt;
	} = $props();

	const token_count = $derived(prompt.token_count);
</script>

<Content_Stats {token_count} />
