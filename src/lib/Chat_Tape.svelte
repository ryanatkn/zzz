<script lang="ts">
	import {scale} from 'svelte/transition';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import type {Tape} from '$lib/multichat.svelte.js';
	import Chat_Message from '$lib/Chat_Message.svelte';

	interface Props {
		tape: Tape;
		onremove: () => void;
		onsend: (input: string) => void;
	}

	const {tape, onremove, onsend}: Props = $props();

	let input = $state('');
	let input_el: HTMLTextAreaElement | undefined;

	function send() {
		const parsed = input.trim();
		if (!parsed) {
			input_el?.focus();
			return;
		}
		onsend(parsed);
		input = '';
	}
</script>

<!-- TODO `duration_2` is the Moss variable for 200ms and 1 for 80ms, but it's not in a usable form -->
<div class="chat_tape" transition:scale={{duration: 200}}>
	<div class="header">
		<header>
			<div class="size_lg">{tape.model.name}</div>
			<small>{tape.model.provider_name}</small>
		</header>
		<Confirm_Button onclick={onremove} />
	</div>

	<div class="messages">
		{#each tape.messages as message (message.id)}
			<Chat_Message {message} />
		{/each}
	</div>

	<div class="flex gap_sm">
		<textarea
			class="flex_1 mb_0"
			bind:value={input}
			bind:this={input_el}
			placeholder="send to this tape..."
			onkeydown={(e) => e.key === 'Enter' && !e.shiftKey && (send(), e.preventDefault())}
		></textarea>
		<button type="button" onclick={() => send()}>send</button>
	</div>
</div>

<style>
	.chat_tape {
		border: var(--border_size_1) solid #ccc;
		padding: var(--space_md);
		display: flex;
		flex-direction: column;
		gap: var(--space_md);
		background-color: var(--input_fill);
		border-radius: var(--radius_xs);
	}
	.header {
		display: flex;
		justify-content: space-between;
	}
	.messages {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		max-height: 400px;
		overflow-y: auto;
	}
</style>
