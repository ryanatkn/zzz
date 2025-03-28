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
</script>

<div class="column_fluid flex_1">
	<div class="column width_md min_width_sm h_100 p_sm">
		{#if tape}
			<Chat_Tape
				{tape}
				onremove={() => chat.remove_tape(tape.id)}
				onsend={(input: string) => chat.send_to_tape(tape.id, input)}
				attrs={{class: 'h_100'}}
			/>
		{:else}
			<Chat_Tape_Add_By_Model {chat} />
		{/if}
	</div>
</div>
