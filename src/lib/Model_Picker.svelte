<script lang="ts">
	import Picker from '$lib/Picker.svelte';
	import Model_Listitem from '$lib/Model_Listitem.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Model} from '$lib/model.svelte.js';
	import {sort_by_text} from '$lib/sortable.svelte.js';

	const zzz = zzz_context.get();
	const {models} = zzz;

	interface Props {
		onpick: (model: Model | undefined) => boolean | void;
		filter?: ((model: Model) => boolean) | undefined;
	}

	const {onpick, filter}: Props = $props();
</script>

<Picker
	items={models.ordered_by_name}
	{onpick}
	{filter}
	sorters={[
		sort_by_text<Model>('name_asc', 'name (a-z)', 'name'),
		sort_by_text<Model>('name_desc', 'name (z-a)', 'name', 'desc'),
		sort_by_text<Model>('provider_asc', 'provider (a-z)', 'provider_name'),
		sort_by_text<Model>('provider_desc', 'provider (z-a)', 'provider_name', 'desc'),
	]}
	sort_key_default="name_asc"
	show_sort_controls
	heading="Pick a model"
>
	{#snippet children(model, pick)}
		<button type="button" class="listitem compact w_100" onclick={() => pick(model)}>
			<Model_Listitem {model} />
		</button>
	{/snippet}
</Picker>
