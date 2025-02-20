<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';
	import ollama from 'ollama/browser';

	import {Multichat} from '$lib/multichat.svelte.js';
	import Model_Selector from '$lib/Model_Selector.svelte';
	import Chat_Tape from '$lib/Chat_Tape.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();

	// TODO BLOCK this needs to be persisted state
	const multichat = new Multichat(zzz);
	multichat.add_tape(zzz.models.find((m) => m.name === 'llama3.2:1b')!);
	let main_input = $state('');
	let pending = $state(false);
	let input_el: HTMLTextAreaElement | undefined;

	const send_to_all = async () => {
		if (!count) return;
		const parsed = main_input.trim();
		if (!parsed) {
			input_el?.focus();
			return;
		}
		pending = true;
		const r = await ollama.chat({
			model: 'llama3.2:1b',
			messages: [{role: 'user', content: parsed}],
		});
		console.log(`ollama browser response`, r);
		await multichat.send_to_all(parsed);
		main_input = '';
		pending = false;
	};

	const count = $derived(multichat.tapes.length);

	// TODO BLOCK custom buttons section - including quick local, smartest all, all, etc

	// TODO BLOCK make a component for the confirm X on the "remove all tapes" button below
</script>

<div class="multichat">
	<div class="column gap_md">
		<div class="panel p_sm">
			<header class="size_xl mb_md">Add tapes to chat</header>
			<!-- TODO add user-customizable sets of models -->
			<menu class="unstyled column">
				<button
					class="w_100 justify_content_start plain"
					type="button"
					onclick={() => {
						for (const model of zzz.models) {
							multichat.add_tape(model);
						}
					}}>add one of each</button
				>
				<button
					class="w_100 justify_content_start plain"
					type="button"
					onclick={() => {
						for (const model of zzz.models) {
							if (model.tags.includes('small')) {
								multichat.add_tape(model);
							}
						}
					}}>add small models</button
				>
				<button
					class="w_100 justify_content_start plain"
					type="button"
					onclick={() => {
						for (const model of zzz.models) {
							if (model.tags.includes('smart')) {
								multichat.add_tape(model);
							}
						}
					}}>add smart models</button
				>
				<!-- TODO add custom buttons -->
			</menu>
		</div>
		<div class="panel p_sm">
			<header class="size_xl mb_md">Add tape with model</header>
			<Model_Selector onselect={(model) => multichat.add_tape(model)} />
		</div>
	</div>
	<div class="panel p_sm flex_1">
		<div class="main_input">
			<textarea
				bind:value={main_input}
				bind:this={input_el}
				placeholder="send to all {count >= 2 ? count + ' ' : ''}tapes..."
			></textarea>
			<Pending_Button {pending} onclick={send_to_all}>
				send to all ({count})
			</Pending_Button>
		</div>
		<div class="my_lg">
			<button type="button" onclick={() => multichat.remove_all_tapes()} disabled={!count}
				>🗙 remove all tapes</button
			>
		</div>
		<!-- TODO duplicate tape button -->
		<div class="tapes">
			{#each multichat.tapes as tape (tape.id)}
				<Chat_Tape
					{tape}
					onremove={() => multichat.remove_tape(tape.id)}
					onsend={(input: string) => multichat.send_to_tape(tape.id, input)}
				/>
			{/each}
		</div>
	</div>
</div>

<style>
	.multichat {
		display: flex;
		align-items: start;
		flex: 1;
		gap: var(--space_md);
	}
	.main_input {
		flex: 1;
		display: flex;
		gap: var(--space_xs);
	}
	.main_input textarea {
		flex: 1;
		min-height: 4rem;
		margin-bottom: 0;
	}
	.tapes {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: var(--space_md);
	}
</style>
