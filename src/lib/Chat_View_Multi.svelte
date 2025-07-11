<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';
	import {slide} from 'svelte/transition';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {Chat} from '$lib/chat.svelte.js';
	import Chat_Tape from '$lib/Chat_Tape.svelte';
	import {GLYPH_ADD, GLYPH_PLACEHOLDER, GLYPH_REMOVE} from '$lib/glyphs.js';
	import Content_Editor from '$lib/Content_Editor.svelte';
	import Model_Picker_Dialog from '$lib/Model_Picker_Dialog.svelte';
	import Glyph from '$lib/Glyph.svelte';

	interface Props {
		chat: Chat;
	}

	const {chat}: Props = $props();

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

	let show_model_picker = $state(false);
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
			focus_key={chat.id}
			bind:pending_element_to_focus_key={
				() => chat.app.ui.pending_element_to_focus_key,
				(v) => {
					chat.app.ui.pending_element_to_focus_key = v;
				}
			}
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

		<div class="display_flex mt_lg">
			<button type="button" class="plain" onclick={() => (show_model_picker = true)}>
				<Glyph glyph={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> add tape
			</button>
			<Confirm_Button
				onconfirm={() => chat.remove_all_tapes()}
				position="right"
				attrs={{disabled: !count, class: 'plain'}}
				><Glyph glyph={GLYPH_REMOVE} attrs={{class: 'mr_xs2'}} /> remove all</Confirm_Button
			>
		</div>
		<ul class="tapes unstyled mt_lg">
			{#each chat.tapes as tape (tape.id)}
				<li in:slide>
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

<Model_Picker_Dialog
	bind:show={show_model_picker}
	onpick={(model) => {
		if (model) {
			chat.add_tape(model); // TODO @many insert at an index via a range input
		}
	}}
/>

<style>
	.tapes {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: var(--space_md);
	}
</style>
