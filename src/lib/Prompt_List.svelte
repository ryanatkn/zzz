<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import {slide} from 'svelte/transition';

	import Prompt_Summary from '$lib/Prompt_Summary.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import type {Chat} from '$lib/chat.svelte.js';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';
	import {Reorderable} from '$lib/reorderable.svelte.js';
	import type {Uuid} from '$lib/zod_helpers.js';

	interface Props {
		chat: Chat;
	}

	const {chat}: Props = $props();

	const reorderable = new Reorderable();

	// Create a derived that filters out already selected prompts
	const unselected_prompts = $derived(
		chat.zzz.prompts.items.filter(
			(p) => !chat.selected_prompts.some((selected) => selected.id === p.id),
		),
	);

	// Track the selected prompt ID
	// svelte-ignore state_referenced_locally
	let selected_prompt_id: Uuid | null = $state(unselected_prompts[0]?.id ?? null);

	// Derive the selected prompt object from the ID
	const selected_prompt = $derived(chat.zzz.prompts.items.find((p) => p.id === selected_prompt_id));

	// TODO can this be refactored away?
	// Reset selection when the available prompts change
	$effect(() => {
		if (unselected_prompts.length && !unselected_prompts.some((p) => p.id === selected_prompt_id)) {
			selected_prompt_id = unselected_prompts[0]?.id ?? null;
		}
	});

	const add_selected_prompt = () => {
		if (selected_prompt) {
			chat.add_selected_prompt(selected_prompt);
			// Automatically select the next available prompt
			selected_prompt_id = unselected_prompts.find((p) => p.id !== selected_prompt_id)?.id ?? null;
		}
	};
</script>

<div class="w_100 column">
	<div class="flex gap_xs align_items_center">
		<select
			class="flex_1 mb_0"
			bind:value={selected_prompt_id}
			disabled={unselected_prompts.length === 0}
		>
			{#each unselected_prompts as prompt (prompt.id)}
				<option value={prompt.id}>{prompt.name} - {prompt.content_truncated}</option>
			{/each}
		</select>
		<button
			type="button"
			class="plain"
			disabled={!selected_prompt || unselected_prompts.length === 0}
			onclick={add_selected_prompt}
		>
			+ add
		</button>
	</div>

	{#if chat.selected_prompts.length > 0}
		<div class="w_100 pt_xs">
			<ul
				class="unstyled column"
				use:reorderable.list={{
					onreorder: (from_index, to_index) => {
						chat.reorder_selected_prompts(from_index, to_index);
					},
				}}
			>
				{#each chat.selected_prompts as prompt, i (prompt.id)}
					<li class="radius_xs p_xs5" use:reorderable.item={{index: i}} transition:slide>
						<div class="flex justify_content_space_between">
							<Copy_To_Clipboard
								text={prompt.content}
								icon_button={false}
								attrs={{
									class: 'plain compact',
									style: 'width: 4rem',
									disabled: !prompt.content,
									title: prompt.content ? 'Copy prompt content' : 'No content to copy',
								}}
							/>
							<div
								class="prompt flex_1 overflow_hidden flex panel px_sm py_xs3 white_space_nowrap size_sm"
							>
								<Prompt_Summary {prompt} />
							</div>
							<Confirm_Button
								onclick={() => chat.remove_selected_prompt(prompt.id)}
								attrs={{
									class: 'plain compact',
									title: `Remove prompt ${prompt.name}`,
								}}
							>
								{GLYPH_REMOVE}
							</Confirm_Button>
						</div>
					</li>
				{/each}
			</ul>
		</div>
	{:else}
		<div class="flex justify_content_end text_align_right pt_xs" transition:slide>
			<blockquote class="p_md fg_1 size_sm mb_0">
				Add prompts from the list and<br />then use copy to add<br />their content to chats
			</blockquote>
		</div>
	{/if}
</div>
