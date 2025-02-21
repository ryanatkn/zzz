<script lang="ts">
	import type {Model} from '$lib/model.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		models?: Array<Model>;
		selected_model: Model; // TODO get from context?
	}

	let {models, selected_model = $bindable()}: Props = $props();

	const zzz = zzz_context.get();

	// TODO cleanup this pattern, but using the fallback isn't reactive, right?
	const final_models = $derived(models ?? zzz.models);
</script>

<div class="row">
	<select bind:value={selected_model}>
		{#each final_models as model (model)}
			<option value={model}>{model.name}</option>
		{/each}
	</select>
</div>
