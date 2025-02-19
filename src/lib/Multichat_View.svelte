<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';

	import {Multichat} from '$lib/multichat.svelte.js';
	import Model_Selector from '$lib/Model_Selector.svelte';
	import Chat_Tape from '$lib/Chat_Tape.svelte';
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

	// TODO BLOCK make a component for the confirm X on the "remove all tapes" button below
</script>

<div class="multichat">
	<div class="panel p_sm">
		<header class="size_xl mb_md">Add tapes</header>
		<Model_Selector onselect={(model) => multichat.add_tape(model)} />
	</div>
	<div class="panel p_sm flex_1">
		<div class="main_input">
			<textarea
				bind:value={main_input}
				bind:this={input_el}
				placeholder="send to all {multichat.tapes.length >= 2
					? multichat.tapes.length + ' '
					: ''}tapes..."
			></textarea>
			<Pending_Button {pending} onclick={send_to_all}>
				send to all ({multichat.tapes.length})
			</Pending_Button>
		</div>
		<div class="mb_lg">
			<button
				type="button"
				onclick={() => multichat.remove_all_tapes()}
				disabled={!multichat.tapes.length}>🗙 remove all tapes</button
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
		gap: 0.5rem;
	}
	.main_input textarea {
		flex: 1;
		min-height: 4rem;
	}
	.tapes {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: var(--space_md);
	}
</style>
