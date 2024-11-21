<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Agent_View from '$lib/Agent_View.svelte';

	// interface Props {}

	// const {}: Props = $props();

	const zzz = zzz_context.get();

	const {agents} = $derived(zzz);

	let pending = $state(false);

	let value = $state('the traveler stopped and spoke to the three AIs, ');

	let textarea_el: HTMLTextAreaElement | undefined = $state();

	const onsubmit = async () => {
		const text = value;
		pending = true;
		// TODO BLOCK create an object locally that doesn't have its response yet, has the request
		// use its toJSON in the server
		await Promise.all(
			agents.map(async (agent) => zzz.send_prompt(text, agent, agent.selected_model_name)), // TODO `agent.selected_model_name` needs to be granular per instance
		);
		pending = false;
		if (text === value) value = '';
	};
</script>

<!-- TODO instead of a `"prompt"` placeholder show a contextmenu with recent history onfocus -->
<textarea bind:this={textarea_el} placeholder="prompt" bind:value></textarea>
<Pending_Button
	{pending}
	onclick={() => {
		if (!value) {
			textarea_el?.focus();
			return;
		}
		void onsubmit();
	}}
>
	send prompt ⚟
</Pending_Button>
<div class="w_100 flex py_lg">
	{#each agents as agent (agent)}
		<Agent_View {agent} />
	{/each}
</div>
