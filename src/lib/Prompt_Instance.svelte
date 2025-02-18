<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Provider_View from '$lib/Provider_View.svelte';
	import Model_Select from '$lib/Model_Select.svelte';
	import type {Provider} from '$lib/provider.svelte.js';
	import type {Model_Json} from '$lib/model.svelte.js';
	import {models_default} from '$lib/config.js';

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

	let model: Model_Json = $state(models_default[0]);
</script>

<!-- TODO these are just a hack -->
<div class="row">
	<Model_Select bind:selected_model={model} />
</div>
<!-- TODO instead of a `"prompt"` placeholder show a contextmenu with recent history onfocus -->

<label>
	{provider.title}
	{model.name}
	<textarea bind:this={textarea_el} placeholder="prompt" bind:value></textarea>
</label>
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
	⚟ send prompt
</Pending_Button>
<div class="w_100 flex py_lg">
	<Provider_View {provider} />
</div>
