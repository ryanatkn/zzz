<script lang="ts">
	import Alert from '@ryanatkn/fuz/Alert.svelte';
	import PendingAnimation from '@ryanatkn/fuz/PendingAnimation.svelte';
	import {resolve} from '$app/paths';

	import ModelDetail from '$lib/ModelDetail.svelte';
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
		<PendingAnimation />
	{:else if has_error}
		<Alert status="error">
			error loading models: {error_message}
		</Alert>
	{:else if model}
		<ModelDetail {model} />
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
