<script lang="ts">
	import Multiprompt from '$lib/Multiprompt.svelte';
	import Prompt_Instance from '$lib/Prompt_Instance.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Provider_Name} from '$lib/provider.svelte.js';
	import Chat from '$lib/Chat.svelte';
	import {SYSTEM_MESSAGE_DEFAULT} from '$lib/config.js';

	const zzz = zzz_context.get();

	// TODO BLOCK get this source of truth right, on the completion_threads, with multi-select as appropriate
	const selected_provider_names: Array<Provider_Name> = $state(['chatgpt']);

	const providers = $derived(zzz.providers.filter((a) => selected_provider_names.includes(a.name))); // TODO hacky assertion

	// TODO BLOCK do the `Chat` integration correctly

	// TODO BLOCK get the system_message correctly (and make sure it's added to the protocol) - maybe radio buttons for them?

	// TODO BLOCK the provider should be inferred from the model
</script>

<section>
	<p>system_message: <code>{SYSTEM_MESSAGE_DEFAULT}</code></p>
	{#each zzz.completion_threads.all as completion_thread (completion_thread)}
		<Chat provider={completion_thread.providers[0]} items={zzz.completion_threads.all} />
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
		<Prompt_Instance provider={completion_thread.providers[0]} />
		<!-- <p>{completion_thread.id}</p>
	<p>{completion_thread.provider_name}</p>
	<p>{completion_thread.created_at}</p> -->
	{/each}
</section>
<section>
	<button type="button" onclick={() => zzz.completion_threads.create_completion_thread(providers)}
		>⨁ create new completion thread</button
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
