<script lang="ts">
	import type {Model_Json} from '$lib/model.svelte.js';
	import {default_models} from '$lib/config.js';

	interface Props {
		models?: Array<Model_Json>;
		selected_model: Model_Json; // TODO get from context?
	}

	let {models = default_models, selected_model = $bindable()}: Props = $props();
</script>

<div class="row">
	<select bind:value={selected_model}>
		{#each models as model (model)}
			<option value={model}>{model.name}</option>
		{/each}
	</select>
</div>
