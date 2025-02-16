<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Provider_View from '$lib/Provider_View.svelte';
	import type {Provider} from '$lib/provider.svelte.js';

	interface Props {
		provider: Provider;
	}

	const {provider}: Props = $props();

	// TODO BLOCK name with `Multiprompt` and `Completion_Thread_View`, maybe `Completion_Thread_Item`?

	const zzz = zzz_context.get();

	let pending = $state(false);

	let value = $state('');

	let textarea_el: HTMLTextAreaElement | undefined = $state();

	const onsubmit = async () => {
		const text = value;
		pending = true;
		// TODO BLOCK create an object locally that doesn't have its response yet, has the request
		// use its toJSON in the server
		await zzz.send_prompt(text, provider, provider.selected_model_name); // TODO `provider.selected_model_name` needs to be granular per instance
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
	<Provider_View {provider} />
</div>
