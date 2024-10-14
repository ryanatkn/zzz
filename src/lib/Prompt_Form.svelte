<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';

	import type {Agent} from '$lib/agent.svelte.js';

	interface Props {
		agent: Agent;
		onsubmit: (value: string) => void;
		pending: boolean;
	}

	const {agent, onsubmit, pending}: Props = $props();

	let value = $state('');

	let textarea_el: HTMLTextAreaElement | undefined;

	// TODO connect `Claude` to the server data in `src/routes/gui/gui.server.svelte`
</script>

<textarea bind:this={textarea_el} placeholder="prompt" bind:value></textarea>
<Pending_Button
	{pending}
	onclick={() => {
		if (!value) {
			textarea_el?.focus();
			return;
		}
		onsubmit(value);
	}}
>
	prompt {agent.title}
</Pending_Button>
