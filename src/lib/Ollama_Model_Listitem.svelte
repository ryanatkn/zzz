<script lang="ts">
	// @slop claude_sonnet_4

	import Ollama_Model_Status from '$lib/Ollama_Model_Status.svelte';
	import Contextmenu_Model from '$lib/Contextmenu_Model.svelte';
	import {format_gigabytes} from '$lib/format_helpers.js';
	import type {Model} from '$lib/model.svelte.js';

	interface Props {
		model: Model;
		onclick?: () => void;
	}

	const {model, onclick = () => ollama.select(model)}: Props = $props();

	const {ollama} = $derived(model.app);

	// TODO move to model?

	const selected = $derived(
		ollama.manager_selected_view === 'model'
			? ollama.manager_selected_model?.id === model.id
			: ollama.manager_selected_view === 'pull'
				? ollama.pull_model_name === model.name
				: false,
	);
</script>

<Contextmenu_Model {model}>
	<button
		type="button"
		class="menu_item selectable plain text_align_start p_sm border_radius_0 font_weight_400"
		class:selected
		{onclick}
	>
		<div class="display_flex flex_column gap_xs w_100">
			<div class="display_flex justify_content_space_between align_items_center">
				<div class="ellipsis font_size_lg">
					{model.name}
				</div>
				<Ollama_Model_Status {model} {ollama} />
			</div>
			{#if model.filesize}
				<div class="font_size_sm">
					{format_gigabytes(model.filesize)}
				</div>
			{/if}
		</div>
	</button>
</Contextmenu_Model>
