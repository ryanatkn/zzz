<script lang="ts">
	import {fade} from 'svelte/transition';

	import type {Model} from '$lib/model.svelte.js';
	import type {Ollama} from '$lib/ollama.svelte.js';

	interface Props {
		model: Model;
		ollama: Ollama;
	}

	const {model, ollama}: Props = $props();

	// TODO BLOCK refactor with Ollama_Manager for ps polling

	const is_running = $derived(ollama.running_model_names.has(model.name));
</script>

{#if is_running}
	<div
		class="display_inline_flex align_items_center gap_xs color_b font_size_sm"
		transition:fade={{duration: 200}}
	>
		<div class="w_xs2 h_xs2 bg_b_5 border_radius_100"></div>
		<span>loaded</span>
	</div>
{/if}
