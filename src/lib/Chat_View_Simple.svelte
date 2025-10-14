<script lang="ts">
	import type {Chat} from '$lib/chat.svelte.js';
	import type {Thread} from '$lib/thread.svelte.js';
	import Chat_Thread from '$lib/Chat_Thread.svelte';
	import Chat_Thread_Add_By_Model from '$lib/Chat_Thread_Add_By_Model.svelte';
	import Chat_Thread_Manage_By_Tag from '$lib/Chat_Thread_Manage_By_Tag.svelte';

	const {
		chat,
		thread,
	}: {
		chat: Chat;
		thread: Thread | undefined;
	} = $props();

	const turn_count = $derived(thread?.turns.size);

	const empty = $derived(!turn_count);
</script>

<!-- TODO the overflow change is hacky, allows the shadow to overlap the sidebar -->
{#if thread}
	<div
		class="column_fluid column flex_1"
		class:pr_xl={empty}
		style:overflow={empty ? 'visible' : undefined}
		style:justify-content={empty ? 'center' : undefined}
	>
		<!-- the two `p_sm` are expected to stay in sync so the size is the same regardless of presentation style -->
		<div
			class="column width_upto_md width_atleast_sm"
			class:height_100={!empty}
			class:p_sm={!empty}
		>
			<Chat_Thread
				{thread}
				onsend={(input) => chat.send_to_thread(thread.id, input)}
				attrs={{class: empty ? 'floating p_sm' : 'height_100'}}
				focus_key={chat.id}
				bind:pending_element_to_focus_key={
					() => chat.app.ui.pending_element_to_focus_key,
					(v) => {
						chat.app.ui.pending_element_to_focus_key = v;
					}
				}
			/>
		</div>
	</div>
{:else}
	<section class="column_section">
		<Chat_Thread_Add_By_Model {chat} />
	</section>
	<section class="column_section">
		<Chat_Thread_Manage_By_Tag {chat} />
	</section>
{/if}
