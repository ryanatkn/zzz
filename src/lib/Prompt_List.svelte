<script lang="ts">
	import {slide} from 'svelte/transition';

	import Prompt_Listitem from './Prompt_Listitem.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {sort_by_text, sort_by_numeric} from '$lib/sortable.svelte.js';
	import type {Prompt} from '$lib/prompt.svelte.js';
	import Sortable_List from '$lib/Sortable_List.svelte';

	const zzz = zzz_context.get();
	const {prompts} = zzz;
	const selected_prompt_id = $derived(prompts.selected_id);

	// TODO BLOCK updated isn't being updated when stuff changes in the prompt
</script>

<Sortable_List
	items={prompts.ordered_items}
	show_sort_controls={prompts.show_sort_controls}
	sorters={[
		sort_by_numeric<Prompt>('updated_newest', 'updated (newest)', 'updated', 'desc'),
		sort_by_numeric<Prompt>('updated_oldest', 'updated (oldest)', 'updated', 'asc'),
		sort_by_numeric<Prompt>('created_newest', 'created (newest)', 'created', 'desc'),
		sort_by_numeric<Prompt>('created_oldest', 'created (oldest)', 'created', 'asc'),
		sort_by_text<Prompt>('name_asc', 'name (a-z)', 'name'),
		sort_by_text<Prompt>('name_desc', 'name (z-a)', 'name', 'desc'),
	]}
	sort_key_default="updated_newest"
>
	{#snippet children(prompt)}
		<div transition:slide>
			<Prompt_Listitem {prompt} selected={prompt.id === selected_prompt_id} />
		</div>
	{/snippet}
</Sortable_List>
