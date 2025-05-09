<script lang="ts">
	import type {Model} from '$lib/model.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();

	interface Props {
		selected_model: Model; // TODO get from context?
		models?: Array<Model> | undefined;
	}

	// I think I like this pattern of `prop_` aliasing for situations like this because
	// it makes acciental use less likely, the `final_models` pattern is more error-prone
	let {models = zzz.models.ordered_by_name, selected_model = $bindable()}: Props = $props();
</script>

<div class="row">
	<select bind:value={selected_model}>
		{#each models as model (model)}
			<option value={model}>{model.name}</option>
		{/each}
	</select>
</div>
