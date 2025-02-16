<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Provider_View from '$lib/Provider_View.svelte';

	// interface Props {}

	// const {}: Props = $props();

	const zzz = zzz_context.get();

	const {providers} = $derived(zzz);

	let pending = $state(false);

	let value = $state(
		'the traveler stopped and faced the three AIs, who then spoke in unison, saying something entirely unexpected with surreal specificity:',
	);

	let textarea_el: HTMLTextAreaElement | undefined = $state();

	const onsubmit = async () => {
		const text = value;
		pending = true;
		// TODO BLOCK create an object locally that doesn't have its response yet, has the request
		// use its toJSON in the server
		await Promise.all(
			providers.map(async (provider) =>
				zzz.send_prompt(text, provider, provider.selected_model_name),
			), // TODO `provider.selected_model_name` needs to be granular per instance
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
	{#each providers as provider (provider)}
		<Provider_View {provider} />
	{/each}
</div>
