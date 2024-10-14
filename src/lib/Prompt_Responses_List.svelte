<script lang="ts">
	import type {SvelteMap} from 'svelte/reactivity';

	import Prompt_Response_Info from '$lib/Prompt_Response_Info.svelte';
	import type {Prompt_Response_Message} from '$lib/zzz_message.js';

	interface Props {
		prompt_responses: SvelteMap<string, Prompt_Response_Message>;
	}

	const {prompt_responses}: Props = $props();
</script>

<ul class="unstyled">
	{#each prompt_responses.values() as prompt_response (prompt_response)}
		<li>
			<Prompt_Response_Info {prompt_response} />
		</li>
	{/each}
</ul>
