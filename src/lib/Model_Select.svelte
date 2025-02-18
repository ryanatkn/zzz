<script lang="ts">
	import type {Model_Json} from '$lib/model.svelte.js';
	import {models_default} from '$lib/config.js';

	interface Props {
		models?: Array<Model_Json>;
		selected_model: Model_Json; // TODO get from context?
	}

	let {models = models_default, selected_model = $bindable()}: Props = $props();
</script>

<div class="row">
	<select bind:value={selected_model}>
		{#each models as model (model)}
			<option value={model}>{model.name}</option>
		{/each}
	</select>
</div>
