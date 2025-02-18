<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';

	import {Multichat} from '$lib/multichat.svelte.js';
	import Model_Selector from '$lib/Model_Selector.svelte';
	import Chat_Stream from '$lib/Chat_Stream.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();

	const multichat = new Multichat(zzz);
	let main_input = $state('');
	let pending = $state(false);
	let input_el: HTMLTextAreaElement | undefined;

	async function send_to_all() {
		const parsed = main_input.trim();
		if (!parsed) {
			input_el?.focus();
			return;
		}
		pending = true;
		await multichat.send_to_all(parsed);
		main_input = '';
		pending = false;
	}
</script>

<div class="multichat">
	<div class="controls">
		<!-- TODO, show the counts of active items for each of the model selector buttons in a snippet here -->
		<div>
			<h3>Add streams</h3>
			<Model_Selector onselect={(model) => multichat.add_stream(model)} />
		</div>
		<div class="flex_1">
			<div class="main-input">
				<textarea
					bind:value={main_input}
					bind:this={input_el}
					placeholder="Send to all {multichat.streams.length >= 2
						? multichat.streams.length + ' '
						: ''}streams..."
				></textarea>
				<Pending_Button {pending} onclick={send_to_all}>
					Send to all ({multichat.streams.length})
				</Pending_Button>
			</div>
			<div>
				<button type="button" onclick={() => multichat.remove_all_streams()}>🗙 remove all</button>
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
