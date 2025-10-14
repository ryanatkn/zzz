<script lang="ts">
	import Alert from '@ryanatkn/fuz/Alert.svelte';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {resolve} from '$app/paths';

	import Model_Detail from '$lib/Model_Detail.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';

	const {params} = $props();

	const app = frontend_context.get();

	const model_name = $derived(params.slug);

	const model = $derived(app.models.find_by_name(model_name));

	// TODO probably refactor, kinda messy
	const {list_status} = $derived(app.ollama);
	const loading = $derived(!model && (list_status === 'initial' || list_status === 'pending'));
	const has_error = $derived(!model && list_status === 'failure');
	const error_message = $derived(app.ollama.list_error);

	// TODO @many consider namespacing under `/llms/`
</script>

<div class="p_sm">
	{#if loading}
		<Pending_Animation />
	{:else if has_error}
		<Alert status="error">
			error loading models: {error_message}
		</Alert>
	{:else if model}
		<Model_Detail {model} />
	{:else}
		<Alert status="error">
			no model found with name "{model_name}", maybe
			<button
				type="button"
				class="inline color_f"
				onclick={() =>
					// TODO UI for choosing provider
					app.models.add({name: model_name, provider_name: 'ollama'})}
			>
				create it
			</button>
			or see the <a href={resolve('/models')}>models</a> or
			<a href={resolve('/providers')}>providers</a>
		</Alert>
	{/if}
</div>
