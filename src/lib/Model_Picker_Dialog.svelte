<script lang="ts">
	import type {ComponentProps, Snippet} from 'svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';

	import Picker_Dialog from '$lib/Picker_Dialog.svelte';
	import Model_Listitem from '$lib/Model_Listitem.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import type {Model} from '$lib/model.svelte.js';
	import {sort_by_text} from '$lib/sortable.svelte.js';

	const app = frontend_context.get();
	const {models} = app;

	let {
		show = $bindable(false),
		onpick,
		filter,
		dialog_props,
		children: children_prop,
	}: {
		show: boolean;
		onpick: (model: Model | undefined) => boolean | void;
		filter?: ((model: Model) => boolean) | undefined;
		dialog_props?: Omit_Strict<ComponentProps<typeof Dialog>, 'children'> | undefined;
		children?: Snippet | undefined;
	} = $props();
</script>

<Picker_Dialog
	bind:show
	items={models.ordered_by_name}
	{onpick}
	{filter}
	{dialog_props}
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
		{#if children_prop}
			{@render children_prop()}
		{/if}
		<button type="button" class="listitem compact width_100" onclick={() => pick(model)}>
			<Model_Listitem {model} />
		</button>
	{/snippet}
</Picker_Dialog>
