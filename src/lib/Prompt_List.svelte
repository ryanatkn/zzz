<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import {slide} from 'svelte/transition';

	import Prompt_Summary from '$lib/Prompt_Summary.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import type {Chat} from '$lib/chat.svelte.js';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';
	import {Reorderable} from '$lib/reorderable.svelte.js';
	import {Bit} from '$lib/bit.svelte.js';
	import Prompt_Picker from '$lib/Prompt_Picker.svelte';

	interface Props {
		chat: Chat;
	}

	const {chat}: Props = $props();

	const reorderable = new Reorderable();

	// Use the new filter method to get unselected prompts efficiently
	const unselected_prompts = $derived(
		chat.zzz.prompts.filter_unselected_prompts(chat.selected_prompts.map((prompt) => prompt.id)),
	);

	// Function to create a new prompt
	const create_new_prompt = async () => {
		const prompt = chat.zzz.prompts.add();

		// Add a starter text bit to the new prompt
		const bit = Bit.create(chat.zzz, {type: 'text'});

		prompt.add_bit(bit);

		// Navigate to the prompt editor
		await chat.zzz.url_params.update_url('prompt', prompt.id);
	};

	// Show/hide the prompt picker
	let show_prompt_picker = $state(false);

	// TODO BLOCK thinking of the usecase here, maybe on the chats page the prompts list is shown twice,
	// once for all and once for the selected, and the all is collapsed by default?
	// or selected filtered out by default, so a single list
</script>

<div class="w_100 column">
	<div class="flex justify_content_start mb_xs">
		<button type="button" class="plain" onclick={create_new_prompt}> + create new prompt </button>
		<button type="button" class="plain" onclick={() => (show_prompt_picker = true)}>
			+ add existing prompt
		</button>
	</div>

	<Prompt_Picker
		bind:show={show_prompt_picker}
		onpick={(prompt) => {
			if (prompt) {
				chat.add_selected_prompt(prompt.id);
			}
		}}
		selected_ids={chat.selected_prompts.map((p) => p.id)}
	/>

	<div class="flex flex_column">
		<div class="overflow_auto flex_1" style:max-height="200px">
			{#if unselected_prompts.length === 0}
				<div class="p_xs size_sm fg_1">No prompts available</div>
			{:else}
				<ul class="unstyled">
					{#each unselected_prompts as prompt (prompt.id)}
						<li class="p_xs size_sm">
							{prompt.name} - {prompt.content_truncated}
						</li>
					{/each}
				</ul>
			{/if}
		</div>
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
								onconfirm={() => chat.remove_selected_prompt(prompt.id)}
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
	{/if}
</div>
