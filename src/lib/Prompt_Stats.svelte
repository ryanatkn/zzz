<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';
	import Bit_Stats from '$lib/Bit_Stats.svelte';

	interface Props {
		prompt: Prompt;
	}

	const {prompt}: Props = $props();
</script>

<Bit_Stats length={prompt.length} token_count={prompt.token_count} />
