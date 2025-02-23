<script lang="ts">
	import type {Model} from '$lib/model.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		models?: Array<Model>;
		selected_model: Model; // TODO get from context?
	}

	// I think I like this pattern of `prop_` aliasing for situations like this because
	// it makes acciental use less likely, the `final_models` pattern is more error-prone
	let {models: prop_models, selected_model = $bindable()}: Props = $props();

	const zzz = zzz_context.get();

	// TODO cleanup this pattern, but using the fallback isn't reactive, right?
	const models = $derived(prop_models ?? zzz.models.items);
</script>

<div class="row">
	<select bind:value={selected_model}>
		{#each models as model (model)}
			<option value={model}>{model.name}</option>
		{/each}
	</select>
</div>
