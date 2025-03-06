<script lang="ts">
	import type {Chat} from '$lib/chat.svelte.js';
	import type {Tape} from '$lib/tape.svelte.js';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';

	interface Props {
		tape: Tape;
		chat: Chat;
	}

	const {tape, chat}: Props = $props();

	// Count messages in the tape
	const message_count = $derived(tape.chat_messages.length);
</script>

<div class="tape_summary panel p_xs">
	<div class="flex justify_content_space_between align_items_center">
		<div class="flex_1">
			<div class="font_weight_600">{tape.model.name}</div>
			<div class="flex gap_xs">
				<small>{message_count} message{message_count !== 1 ? 's' : ''}</small>
			</div>
		</div>
		<div>
			<Confirm_Button
				onclick={() => chat.remove_tape(tape.id)}
				attrs={{class: 'icon_button plain', title: 'Remove tape'}}
			>
				{GLYPH_REMOVE}
			</Confirm_Button>
		</div>
	</div>
</div>

<style>
	.tape_summary:hover {
		background-color: var(--bg_1);
	}
</style>
