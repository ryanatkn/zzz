<script lang="ts">
	import Multiprompt from '$lib/Multiprompt.svelte';
	import Prompt_Instance from '$lib/Prompt_Instance.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Agent_Name} from '$lib/agent.svelte.js';
	import Chat from '$lib/Chat.svelte';

	const zzz = zzz_context.get();

	// TODO BLOCK get this source of truth right, on the completion_threads, with multi-select as appropriate
	const selected_agent_names: Array<Agent_Name> = $state(['chatgpt']);

	const agents = $derived(zzz.agents.filter((a) => selected_agent_names.includes(a.name))); // TODO hacky assertion

	// TODO BLOCK do the `Chat` integration correctly
</script>

<section>
	{#each zzz.completion_threads.all as completion_thread (completion_thread)}
		<Chat items={zzz.completion_threads.all} />
	{/each}
</section>
<section class="dashboard_prompts">
	<div class="w_100 flex_1">
		<Multiprompt />
	</div>
</section>
<section class="w_100 flex_1">
	{#each zzz.completion_threads.all as completion_thread (completion_thread)}
		<!-- TODO hack just to get stuff onscreen -->
		<Prompt_Instance agent={completion_thread.agents[0]} />
		<!-- <p>{completion_thread.id}</p>
	<p>{completion_thread.agent_name}</p>
	<p>{completion_thread.created_at}</p> -->
	{/each}
</section>
<section>
	<button type="button" onclick={() => zzz.completion_threads.create_completion_thread(agents)}
		>create new completion thread</button
	>
</section>

<style>
	.dashboard_prompts {
		display: flex;
		width: 100%;
		padding: var(--space_md);
		gap: var(--space_md);
	}
</style>
