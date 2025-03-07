<script lang="ts">
	import {slide} from 'svelte/transition';

	import type {Chat} from '$lib/chat.svelte.js';
	import {Reorderable} from '$lib/reorderable.svelte.js';
	import Tape_Summary from '$lib/Tape_Summary.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		chat?: Chat;
	}

	const {chat = zzz_context.get().chats.selected}: Props = $props();

	const reorderable = new Reorderable();

	// Define a shared reorder handler
	const handle_reorder = (from_index: number, to_index: number) => {
		if (chat) {
			chat.reorder_tapes(from_index, to_index);
		}
	};
</script>

<div class="column">
	{#if chat}
		<ul
			class="unstyled column gap_xs5"
			use:reorderable.list={{
				onreorder: handle_reorder,
			}}
		>
			{#each chat.tapes as tape, i (tape.id)}
				<li class="radius_xs" use:reorderable.item={{index: i}} transition:slide>
					<Tape_Summary {tape} {chat} />
				</li>
			{/each}
		</ul>
	{:else}
		<p class="text_align_center">No chat selected</p>
	{/if}
</div>
