<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Prompt_Responses_List from '$lib/Prompt_Responses_List.svelte';

	interface Props {}

	const {}: Props = $props();

	const zzz = zzz_context.get();

	const {agents} = $derived(zzz);

	let pending = $state(false);

	let value = $state('');

	let textarea_el: HTMLTextAreaElement | undefined;

	const onsubmit = async () => {
		const text = value;
		pending = true;
		// TODO BLOCK create a prompt locally that doesn't have its response yet
		await zzz.send_prompt(value);
		pending = false;
		if (text === value) value = '';
	};
</script>

{#each agents.values() as agent (agent)}
	<!-- TODO pass a zap? -->
	<textarea bind:this={textarea_el} placeholder="prompt" bind:value></textarea>

	<Prompt_Responses_List {agent} prompt_responses={zzz.prompt_responses} />
{/each}
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
	send prompt
</Pending_Button>
