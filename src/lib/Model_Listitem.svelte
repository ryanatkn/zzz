<script lang="ts">
	import type {Model} from '$lib/model.svelte.js';

	interface Props {
		model: Model;
	}

	const {model}: Props = $props();

	const provider = $derived(model.zzz.providers.find_by_name(model.provider_name));

	// TODO maybe rename to Model_Listitem, particularly if we add a `Model_List` for the parent usage
</script>

<!-- TODO add Contextmenu_Model -->
<div class="row w_100">
	<div class="flex_1">
		<div class="size_lg mb_xs">
			{model.name}
		</div>
		<div class="mb_xs">
			{provider?.name}{#if model.context_window}, <span
					>{(model.context_window / 1000).toFixed(0)}k context</span
				>{/if}
		</div>
	</div>

	{#if model.tags.length}
		<ul class="unstyled flex flex_wrap gap_xs2">
			{#each model.tags as tag (tag)}
				<small class="chip font_weight_400">{tag}</small>
			{/each}
		</ul>
	{/if}
</div>
