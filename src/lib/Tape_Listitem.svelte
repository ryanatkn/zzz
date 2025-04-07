<script lang="ts">
	import type {Chat} from '$lib/chat.svelte.js';
	import type {Tape} from '$lib/tape.svelte.js';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Contextmenu_Tape from '$lib/Contextmenu_Tape.svelte';
	import Tape_Toggle_Button from '$lib/Tape_Toggle_Button.svelte';

	interface Props {
		tape: Tape;
		chat: Chat;
	}

	const {tape, chat}: Props = $props();

	const message_count = $derived(tape.strips.length);
</script>

<Contextmenu_Tape {tape}>
	<div class="tape_summary panel p_xs" class:dormant={!tape.enabled}>
		<div class="row justify_content_space_between">
			<div class="flex_1">
				<div class="font_weight_600">{tape.model_name}</div>
				<div class="flex gap_xs">
					{#if message_count > 0}
						<small
							>{message_count} message{message_count !== 1 ? 's' : ''}, {tape.token_count} token{tape.token_count !==
							1
								? 's'
								: ''}</small
						>
					{:else}&nbsp;
					{/if}
				</div>
			</div>
			<div class="flex gap_xs">
				<Tape_Toggle_Button {tape} />
				<Confirm_Button
					onconfirm={() => chat.remove_tape(tape.id)}
					attrs={{class: 'icon_button plain', title: 'delete tape'}}
				>
					{GLYPH_REMOVE}
				</Confirm_Button>
			</div>
		</div>
	</div>
</Contextmenu_Tape>

<style>
	.tape_summary:hover {
		background-color: var(--bg_1);
	}
</style>
