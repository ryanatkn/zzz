<script lang="ts">
	import type {Model} from '$lib/model.svelte.js';

	interface Props {
		model: Model;
		show_tags?: boolean | undefined;
	}

	const {model, show_tags}: Props = $props();

	const provider = $derived(model.zzz.providers.find_by_name(model.provider_name));
</script>

<!-- TODO add Contextmenu_Model -->
<div class="w_100 py_sm">
	<div class="font_size_md">
		{model.name}
	</div>
	<div class="row justify_content_space_between">
		<span>{provider?.name}</span>{#if model.context_window_formatted}<span
				>{model.context_window_formatted}</span
			>{/if}
	</div>

	{#if show_tags && model.tags.length}
		<ul class="unstyled display_flex flex_wrap gap_xs2">
			{#each model.tags as tag (tag)}
				<small class="chip font_weight_400">{tag}</small>
			{/each}
		</ul>
	{/if}
</div>
