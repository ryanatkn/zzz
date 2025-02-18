<script lang="ts">
	import {Multichat} from '$lib/multichat.svelte.js';
	import Model_Selector from '$lib/Model_Selector.svelte';
	import Chat_Stream from '$lib/Chat_Stream.svelte';
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';

	const multichat = new Multichat();
	let main_input = $state('');
	let pending = $state(false);

	async function send_to_all() {
		if (!main_input.trim()) return;
		pending = true;
		await multichat.send_to_all(main_input);
		main_input = '';
		pending = false;
	}
</script>

<div class="multichat">
	<div class="controls">
		<Model_Selector onselect={(model) => multichat.add_stream(model)} />
		<div class="main-input">
			<textarea bind:value={main_input} placeholder="Send to all streams..."></textarea>
			<Pending_Button {pending} onclick={send_to_all}>
				Send to all ({multichat.streams.length})
			</Pending_Button>
		</div>
	</div>

	<div class="streams">
		{#each multichat.streams as stream (stream.id)}
			<Chat_Stream
				{stream}
				onremove={() => multichat.remove_stream(stream.id)}
				onsend={(input: string) => multichat.send_to_stream(stream.id, input)}
			/>
		{/each}
	</div>
</div>

<style>
	.multichat {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}
	.controls {
		display: flex;
		gap: 1rem;
		align-items: flex-start;
	}
	.main-input {
		flex: 1;
		display: flex;
		gap: 0.5rem;
	}
	.main-input textarea {
		flex: 1;
		min-height: 4rem;
	}
	.streams {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: 1rem;
	}
</style>
