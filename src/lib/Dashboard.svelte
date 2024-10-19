<script lang="ts">
	import {zzz_context} from '$lib/zzz.svelte.js';
	import File_List from '$lib/File_List.svelte';
	import Multiprompt from '$lib/Multiprompt.svelte';
	import Prompt_Instance from '$lib/Prompt_Instance.svelte';
	import type {Agent_Name} from '$lib/agent.svelte.js';

	// interface Props {}

	// const {}: Props = $props();

	const zzz = zzz_context.get();

	// TODO BLOCK get this source of truth right, on the tapes, with multi-select as appropriate
	const selected_agent_names: Agent_Name[] = $state(['chatgpt']);

	const agents = $derived(zzz.agents.filter((a) => selected_agent_names.includes(a.name))); // TODO hacky assertion
</script>

<!-- TODO drive with data -->
<section class="dashboard_prompts">
	<div class="w_100 flex_1">
		<Multiprompt />
	</div>
</section>
<section class="w_100 flex_1">
	{#each zzz.tapes.all as tape (tape)}
		<!-- TODO hack just to get stuff onscreen -->
		<Prompt_Instance agent={tape.agents[0]} />
		<!-- <p>{tape.id}</p>
			<p>{tape.agent_name}</p>
			<p>{tape.created_at}</p> -->
	{/each}
</section>
<section>
	<button type="button" onclick={() => zzz.tapes.create_tape(agents)}>create new tape</button>
</section>
<section>
	<File_List files={zzz.files_by_id} />
</section>

<style>
	.dashboard_prompts {
		display: flex;
		width: 100%;
		padding: var(--space_md);
		gap: var(--space_md);
	}
</style>
