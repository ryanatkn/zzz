<script lang="ts">
	import type {Model} from '$lib/model.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		onselect: (model: Model) => void;
	}

	const {onselect}: Props = $props();

	const zzz = zzz_context.get();

	const all_models = $derived(zzz.providers.flatMap((p) => p.models));
</script>

<div class="model-selector">
	<select
		onchange={(e) => {
			const model = all_models.find((m) => m.name === e.currentTarget.value);
			if (model) onselect(model);
			e.currentTarget.value = ''; // Reset select after use
		}}
	>
		<option value="">Add chat stream...</option>
		{#each all_models as model}
			<option value={model.name}>
				{model.name} ({model.provider_name})
			</option>
		{/each}
	</select>
</div>
