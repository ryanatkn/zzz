<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';
	import Prompt_Fragment_Stats from '$lib/Prompt_Fragment_Stats.svelte';

	interface Props {
		prompt: Prompt;
	}

	const {prompt}: Props = $props();
</script>

<Prompt_Fragment_Stats length={prompt.length} token_count={prompt.token_count} />
