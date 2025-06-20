<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';
	import Content_Stats from '$lib/Content_Stats.svelte';

	interface Props {
		prompt: Prompt;
	}

	const {prompt}: Props = $props();

	const token_count = $derived(prompt.token_count);
</script>

<Content_Stats {token_count} />
