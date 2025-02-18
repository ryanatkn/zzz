<script lang="ts">
	import {slide} from 'svelte/transition';

	import type {Model} from '$lib/model.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();

	interface Props {
		models?: Array<Model>;
		onselect: (model: Model) => void;
	}

	const {models = zzz.models, onselect}: Props = $props();
</script>

<ul class="model-selector unstyled">
	{#each models as model (model)}
		<li value={model.name} class="display_contents" transition:slide>
			<button type="button" class="plain w_100" onclick={() => onselect(model)}
				><div class="w_100 text_align_left">
					<div class="font_weight_500">{model.name}</div>
					<div class="size_sm font_weight_400">{model.provider_name}</div>
				</div></button
			>
		</li>
	{/each}
</ul>
