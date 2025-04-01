<script lang="ts">
	import Picker from '$lib/Picker.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Prompt} from '$lib/prompt.svelte.js';
	import Prompt_Summary from '$lib/Prompt_Summary.svelte';
	import type {Uuid} from '$lib/zod_helpers.js';
	import {sort_by_text, sort_by_numeric} from '$lib/sortable.svelte.js';

	interface Props {
		onpick: (prompt: Prompt | undefined) => boolean | void;
		show?: boolean | undefined;
		filter?: ((prompt: Prompt) => boolean) | undefined;
		exclude_ids?: Array<Uuid> | undefined;
		selected_ids?: Array<Uuid> | undefined;
	}

	let {onpick, show = $bindable(false), filter, exclude_ids, selected_ids}: Props = $props();

	const zzz = zzz_context.get();
	const {prompts} = zzz;
</script>

<Picker
	bind:show
	items={prompts.ordered_items}
	{onpick}
	{filter}
	{exclude_ids}
	sorters={[
		// TODO @many why is the cast needed?
		sort_by_text<Prompt>('name_asc', 'name (a-z)', 'name'),
		sort_by_text<Prompt>('name_desc', 'name (z-a)', 'name', 'desc'),
		sort_by_numeric('created_newest', 'newest first', 'created_date', 'desc'),
		sort_by_numeric('created_oldest', 'oldest first', 'created_date', 'asc'),
	]}
	sort_key_default="name_asc"
	show_sort_controls
	heading="Pick a prompt"
>
	{#snippet children(prompt, pick)}
		<button
			type="button"
			class="listitem compact w_100"
			class:selected={selected_ids?.includes(prompt.id)}
			onclick={() => pick(prompt)}
		>
			<div class="p_xs size_sm">
				<Prompt_Summary {prompt} />
			</div>
		</button>
	{/snippet}
</Picker>
