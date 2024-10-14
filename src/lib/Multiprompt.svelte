<script lang="ts">
	import {zzz_context} from '$lib/zzz.svelte.js';
	import Prompt_Responses_List from '$lib/Prompt_Responses_List.svelte';
	import Prompt_Form from '$lib/Prompt_Form.svelte';

	interface Props {}

	const {}: Props = $props();

	const zzz = zzz_context.get();

	const {pending_prompts} = $derived(zzz);

	// TODO refactor
	let claude_text = $state('');
	let chatgpt_text = $state('');
	let gemini_text = $state('');
</script>

{#each zzz.agents.values() as agent (agent)}
	<!-- TODO pass a zap? -->
	<Prompt_Form
		{agent}
		onsubmit={(text) => {
			void zzz.send_prompt(text, agent);
			if (agent.name === 'claude') {
				claude_text = text;
			} else if (agent.name === 'chatgpt') {
				chatgpt_text = text;
			} else if (agent.name === 'gemini') {
				gemini_text = text;
			} else {
				throw Error('TODO refactor');
			}
		}}
		pending={pending_prompts.has(
			// TODO hacky, refactor with the above
			agent.name === 'claude'
				? claude_text
				: agent.name === 'chatgpt'
					? chatgpt_text
					: agent.name === 'gemini'
						? gemini_text
						: (null as any),
		)}
	/>
	<Prompt_Responses_List {agent} prompt_responses={zzz.prompt_responses} />
{/each}
