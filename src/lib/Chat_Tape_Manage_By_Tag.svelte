<script lang="ts">
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {Chat} from '$lib/chat.svelte.js';

	interface Props {
		chat: Chat;
	}

	const {chat}: Props = $props();

	const {app} = $derived(chat);

	const tags = $derived(Array.from(app.tags)); // TODO refactor, `Tags` may be a class, maybe with an indexed collection
</script>

<div>
	<!-- TODO add user-customizable sets of models -->
	<div class="display_flex">
		<div class="flex_1 p_xs">
			<header class="font_size_lg text_align_center mb_xs">add by tag</header>
			<menu class="unstyled column">
				{#each tags as tag (tag)}
					{@const models_with_tag = app.models.filter_by_tag(tag)}
					<button
						type="button"
						class="w_100 font_size_sm py_xs3 justify_content_space_between plain border_radius_xs font_weight_600"
						style:min-height="0"
						onclick={() => {
							chat.add_tapes_by_model_tag(tag);
						}}
					>
						<span>{tag}</span>
						{#if models_with_tag.length}
							<span>{models_with_tag.length}</span>
						{/if}
					</button>
				{/each}
			</menu>
		</div>
		<div class="flex_1 p_xs fg_1">
			<header class="font_size_lg text_align_center mb_xs">remove by tag</header>
			<menu class="unstyled column">
				{#each tags as tag (tag)}
					<!-- TODO index this -->
					{@const tapes_with_tag = chat.tapes.filter((t) => t.model.tags.includes(tag))}
					<Confirm_Button
						attrs={{
							disabled: !tapes_with_tag.length,
							class:
								'w_100 font_size_sm py_xs3 justify_content_space_between plain border_radius_xs font_weight_600',
							style: 'min-height: 0;',
						}}
						onconfirm={() => {
							chat.remove_tapes_by_model_tag(tag);
						}}
					>
						<span>{tag}</span>
						{#if tapes_with_tag.length}
							<span>{tapes_with_tag.length}</span>
						{/if}
					</Confirm_Button>
				{/each}
			</menu>
		</div>
		<!-- TODO add custom buttons -->
	</div>
</div>
