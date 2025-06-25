<script lang="ts">
	import Alert from '@ryanatkn/fuz/Alert.svelte';
	import {page} from '$app/state';
	import {onMount} from 'svelte';
	import type {Async_Status} from '@ryanatkn/belt/async.js';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import Model_Detail from '$lib/Model_Detail.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import {base} from '$app/paths';

	const app = frontend_context.get();

	let status: Async_Status = $state('initial');
	let error_message: string | undefined = $state(undefined);

	// Initial load when component mounts
	onMount(() => {
		// TODO any way to optimize this?
		// if (model.provider_name === 'ollama') {
		if (model) {
			status = 'success';
		} else {
			status = 'pending';
			void app.ollama.refresh().then(
				() => {
					status = 'success';
				},
				(error) => {
					console.error('error refreshing models:', error);
					error_message = error.message || 'unknown error';
					status = 'failure';
				},
			);
		}
	});

	const name = $derived(page.params.slug);

	const model = $derived(app.models.find_by_name(name));

	// TODO @many consider namespacing under `/llms/`
</script>

<div class="p_sm">
	{#if status === 'initial' || status === 'pending'}
		<Pending_Animation />
	{:else if status === 'failure'}
		<Alert status="error">
			error loading models: {error_message}
		</Alert>
	{:else if model}
		<Model_Detail {model} />
	{:else}
		<Alert status="error">
			no model found with name "{name}", maybe
			<button
				type="button"
				class="inline color_f"
				onclick={() =>
					// TODO UI for choosing provider
					app.models.add({name, provider_name: 'ollama'})}
			>
				create it
			</button>
			or see the <a href="{base}/models">models</a> or
			<a href="{base}/providers">providers</a>
		</Alert>
	{/if}
</div>
