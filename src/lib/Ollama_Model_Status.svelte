<script lang="ts">
	import {fade} from 'svelte/transition';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import type {Model} from '$lib/model.svelte.js';
	import type {Ollama} from '$lib/ollama.svelte.js';

	interface Props {
		model: Model;
		ollama: Ollama;
	}

	const {model, ollama}: Props = $props();

	const running = $derived(ollama.running_model_names.has(model.name));

	const pulling = $derived(ollama.pull_is_pulling(model.name));
</script>

{#if pulling}<Pending_Animation />{/if}
{#if running}
	<div transition:fade={{duration: 200}}>
		<small class="chip">loaded</small>
	</div>
{/if}
