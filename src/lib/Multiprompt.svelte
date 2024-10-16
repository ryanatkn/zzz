<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Agent_View from '$lib/Agent_View.svelte';

	// interface Props {}

	// const {}: Props = $props();

	const zzz = zzz_context.get();

	const {agents} = $derived(zzz);

	let pending = $state(false);

	let value = $state('');

	let textarea_el: HTMLTextAreaElement | undefined = $state();

	const onsubmit = async () => {
		const text = value;
		pending = true;
		// TODO BLOCK create an object locally that doesn't have its response yet, has the request
		// use its toJSON in the server
		await zzz.send_prompt(value);
		pending = false;
		if (text === value) value = '';
	};
</script>

<div class="w_100 flex mb_lg">
	{#each agents.values() as agent (agent)}
		<Agent_View {agent} />
	{/each}
</div>
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
	⚞ send prompt ⚟
</Pending_Button>
