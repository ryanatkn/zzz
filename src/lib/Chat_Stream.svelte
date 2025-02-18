<script lang="ts">
	import type {Chat_Stream} from './multichat.svelte.js';

	interface Props {
		stream: Chat_Stream;
		onremove: () => void;
		onsend: (input: string) => void;
	}

	const {stream, onremove, onsend}: Props = $props();

	let input = $state('');

	function send() {
		if (!input.trim()) return;
		onsend(input);
		input = '';
	}
</script>

<div class="chat-stream">
	<div class="header">
		<h3>{stream.model.name}</h3>
		<button type="button" class="remove" onclick={() => onremove()}>×</button>
	</div>

	<div class="messages">
		{#each stream.messages as message}
			<div class="message">
				<div class="user">{message.text}</div>
				{#if message.response}
					<div class="assistant">
						{message.response.data.type === 'ollama'
							? message.response.data.value.message.content
							: JSON.stringify(message.response.data)}
					</div>
				{/if}
			</div>
		{/each}
	</div>

	<div class="flex gap_sm">
		<textarea
			class="flex_1"
			bind:value={input}
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
