<script lang="ts">
	import type {Chat} from '$lib/chat.svelte.js';
	import type {Tape} from '$lib/tape.svelte.js';
	import Chat_Tape from '$lib/Chat_Tape.svelte';
	import Chat_Tape_Add_By_Model from '$lib/Chat_Tape_Add_By_Model.svelte';

	interface Props {
		chat: Chat;
		tape: Tape | undefined;
	}

	const {chat, tape}: Props = $props();

	const strip_count = $derived(tape?.strips.size);

	const empty = $derived(!strip_count);
</script>

<!-- TODO the overflow change is hacky, allows the shadow to overlap the sidebar, but maybe that should be fixed -->
<div
	class="column_fluid column flex_1"
	style:overflow={empty ? 'visible' : undefined}
	style:justify-content={empty ? 'center' : undefined}
>
	<!-- the two `p_sm` are expected to stay in sync so the size is the same regardless of presentation style -->
	<div class="column width_md min_width_sm" class:h_100={!empty} class:p_sm={!empty}>
		{#if tape}
			<Chat_Tape
				{chat}
				{tape}
				onsend={(input) => chat.send_to_tape(tape.id, input)}
				attrs={{class: empty ? 'floating p_sm' : 'h_100'}}
			/>
		{:else}
			<Chat_Tape_Add_By_Model {chat} />
		{/if}
	</div>
</div>
