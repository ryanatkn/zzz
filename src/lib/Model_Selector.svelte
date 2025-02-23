<script lang="ts">
	import {slide} from 'svelte/transition';
	import type {Snippet} from 'svelte';

	import type {Model} from '$lib/model.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();

	interface Props {
		onselect: (model: Model) => void;
		models?: Array<Model>;
		children?: Snippet<[model: Model]>;
	}

	const {onselect, models = zzz.models.items, children}: Props = $props();

	// TODO layout needs to probably be calculated so we can animate things (see template.fuz.dev for an example)

	// TODO think about an interaction here for better UX - like highlighting the cards on hover or something
</script>

<ul class="unstyled">
	{#each models as model (model)}
		<li value={model.name} class="display_contents" transition:slide>
			<button type="button" class="plain w_100 py_xs3" onclick={() => onselect(model)}
				><div class="flex w_100 text_align_left">
					<div class="flex_1 pr_md">
						<div class="font_weight_500">{model.name}</div>
						<div class="size_sm font_weight_400">{model.provider_name}</div>
					</div>
					<!-- TODO this is arbitrarily placed -->
					{#if children}<div>{@render children(model)}</div>{/if}
				</div></button
			>
		</li>
	{/each}
</ul>
