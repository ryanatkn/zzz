<script lang="ts">
	import {scale} from 'svelte/transition';

	import type {Chat_Stream} from '$lib/multichat.svelte.js';
	import Chat_Message from '$lib/Chat_Message.svelte';

	interface Props {
		stream: Chat_Stream;
		onremove: () => void;
		onsend: (input: string) => void;
	}

	const {stream, onremove, onsend}: Props = $props();

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

	let removing = $state(false);
</script>

<!-- ⨉ -->
<div class="chat-stream" transition:scale>
	<div class="header">
		<h3>{stream.model.name}</h3>
		<div class="relative">
			{#if removing}<button
					type="button"
					class="color_c absolute icon_button"
					style:left="-100%"
					onclick={() => onremove()}>🗙</button
				>{/if}
			<button
				type="button"
				class="icon_button"
				class:plain={!removing}
				onclick={() => (removing = !removing)}
				>{#if removing}×{:else}🗙{/if}</button
			>
		</div>
	</div>

	<div class="messages">
		{#each stream.messages as message}
			<Chat_Message {message} />
		{/each}
	</div>

	<div class="flex gap_sm">
		<textarea
			class="flex_1"
			bind:value={input}
			bind:this={input_el}
			placeholder="Send to this stream..."
			onkeydown={(e) => e.key === 'Enter' && !e.shiftKey && (send(), e.preventDefault())}
		></textarea>
		<button type="button" onclick={() => send()}>Send</button>
	</div>
</div>

<style>
	.chat-stream {
		border: 1px solid #ccc;
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 1rem;
		background-color: var(--input_fill);
		border-radius: var(--radius_xs);
	}
	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}
	.messages {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		max-height: 400px;
		overflow-y: auto;
	}
</style>
