<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';
	import {slide} from 'svelte/transition';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {Chat} from '$lib/chat.svelte.js';
	import Chat_Tape from '$lib/Chat_Tape.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_PLACEHOLDER, GLYPH_REMOVE} from '$lib/glyphs.js';
	import Content_Editor from '$lib/Content_Editor.svelte';
	import Chat_Tape_Add_By_Model from '$lib/Chat_Tape_Add_By_Model.svelte';

	interface Props {
		chat: Chat;
	}

	const {chat}: Props = $props();

	const zzz = zzz_context.get();
	let content_input: {focus: () => void} | undefined;
	let pending = $state(false); // TODO refactor request state

	const send_to_all = async () => {
		if (!count) return;
		const parsed = chat.main_input.trim();
		if (!parsed) {
			content_input?.focus();
			return;
		}
		chat.main_input = '';
		pending = true;
		await chat.send_to_all(parsed);
		pending = false;
	};

	const count = $derived(chat.enabled_tapes.length);
	const tags = $derived(Array.from(zzz.tags)); // TODO BLOCK refactor, `Tags` may be a class, maybe with an indexed collection
</script>

<div class="column_fluid">
	<div class="column_bg_1 p_sm">
		<Content_Editor
			bind:this={content_input}
			bind:content={chat.main_input}
			token_count={chat.main_input_token_count}
			placeholder="{GLYPH_PLACEHOLDER} to {count}"
			show_actions
			show_stats
		>
			<Pending_Button
				{pending}
				onclick={send_to_all}
				disabled={!count ? true : undefined}
				attrs={{class: 'plain'}}
			>
				send to {count}
			</Pending_Button>
		</Content_Editor>

		<div class="flex mt_lg">
			<Confirm_Button
				onconfirm={() => chat.remove_all_tapes()}
				position="right"
				attrs={{disabled: !count, class: 'plain'}}>{GLYPH_REMOVE} remove all</Confirm_Button
			>
		</div>
		<ul class="tapes unstyled mt_lg">
			{#each chat.tapes as tape (tape.id)}
				<li transition:slide>
					<Chat_Tape
						{tape}
						onsend={(input) => chat.send_to_tape(tape.id, input)}
						strips_attrs={{class: 'max_height_sm'}}
						attrs={{class: 'p_md'}}
					/>
				</li>
			{/each}
		</ul>
	</div>
</div>
<div class="column_fixed">
	<div>
		<!-- TODO add user-customizable sets of models -->
		<div class="flex">
			<div class="flex_1 p_xs">
				<header class="size_lg text_align_center mb_xs">add by tag</header>
				<menu class="unstyled column">
					{#each tags as tag (tag)}
						{@const models_with_tag = zzz.models.filter_by_tag(tag)}
						<button
							type="button"
							class="w_100 size_sm py_xs3 justify_content_space_between plain radius_xs font_weight_600"
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
				<header class="size_lg text_align_center mb_xs">remove by tag</header>
				<menu class="unstyled column">
					{#each tags as tag (tag)}
						<!-- TODO index this -->
						{@const tapes_with_tag = chat.tapes.filter((t) => t.model.tags.includes(tag))}
						<Confirm_Button
							attrs={{
								disabled: !tapes_with_tag.length,
								class:
									'w_100 size_sm py_xs3 justify_content_space_between plain radius_xs font_weight_600',
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
	<Chat_Tape_Add_By_Model {chat} />
</div>

<style>
	.tapes {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: var(--space_md);
	}
</style>
