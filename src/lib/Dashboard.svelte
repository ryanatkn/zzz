<script lang="ts">
	import {zzz_context} from '$lib/zzz.svelte.js';
	import File_List from '$lib/File_List.svelte';
	import Multiprompt from '$lib/Multiprompt.svelte';
	import Prompt_Instance from '$lib/Prompt_Instance.svelte';

	// interface Props {}

	// const {}: Props = $props();

	const zzz = zzz_context.get();

	// TODO

	const agent = $derived(zzz.agents.find((a) => a.name === 'gpt')); // TODO hacky assertion
</script>

<!-- TODO drive with data -->
<section class="dashboard_prompts">
	<div class="w_100 flex_1">
		<Multiprompt />
	</div>
</section>
<section class="w_100 flex_1">
	{#if agent}
		<Prompt_Instance {agent} />
	{:else}
		<!-- TODO agent picker -->
		<p>no agent selected</p>
	{/if}
</section>
<section>
	<button type="button" onclick={() => zzz.create_tape(agent)}>create new tape</button>
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
