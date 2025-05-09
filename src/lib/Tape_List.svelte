<script lang="ts">
	import {slide} from 'svelte/transition';

	import type {Chat} from '$lib/chat.svelte.js';
	import {Reorderable} from '$lib/reorderable.svelte.js';
	import Tape_Listitem from '$lib/Tape_Listitem.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		chat?: Chat | undefined;
	}

	const {chat = zzz_context.get().chats.selected}: Props = $props();

	const reorderable = new Reorderable();
</script>

{#if chat}
	<ul
		class="unstyled column gap_xs5"
		use:reorderable.list={{
			onreorder: (from_index, to_index) => {
				chat.reorder_tapes(from_index, to_index);
			},
		}}
	>
		{#each chat.tapes as tape, i (tape.id)}
			<li class="border_radius_xs" use:reorderable.item={{index: i}} transition:slide>
				<Tape_Listitem {tape} {chat} />
			</li>
		{/each}
	</ul>
{:else}
	<p class="text_align_center">No chat selected</p>
{/if}
