<script lang="ts">
	import Messages_List from '$lib/Messages_List.svelte';
	import Message_Detail from '$lib/Message_Detail.svelte';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import {GLYPH_MESSAGE} from '$lib/glyphs.js';
	import type {Message} from '$lib/message.svelte.js';

	let selected_message: Message | null = $state(null);

	const handle_select_message = (message: Message): void => {
		selected_message = message;
	};
</script>

<div class="p_lg h_100">
	<h1><Text_Icon icon={GLYPH_MESSAGE} /> messages</h1>
	<p>System messages between client and server.</p>

	<div class="grid mt_md h_100" style="grid-template-columns: 320px 1fr; gap: var(--space_md)">
		<div class="overflow_y_auto border_right">
			<Messages_List
				limit={100}
				selected_message_id={selected_message?.id}
				onselect={handle_select_message}
			/>
		</div>

		<div class="panel p_md overflow_y_auto h_100">
			{#if selected_message}
				<Message_Detail message={selected_message} />
			{:else}
				<div class="flex align_items_center justify_content_center h_100">
					<p>Select a message from the list to view its details</p>
				</div>
			{/if}
		</div>
	</div>
</div>

<style>
	.border_right {
		border-right: 1px solid var(--color_border);
	}
</style>
