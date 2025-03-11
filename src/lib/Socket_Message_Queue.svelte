<script lang="ts">
	import {slide} from 'svelte/transition';
	import {format} from 'date-fns';
	import {SvelteMap} from 'svelte/reactivity';

	import type {Socket, Queued_Message, Failed_Message} from '$lib/socket.svelte.js';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {
		GLYPH_RETRY,
		GLYPH_DELETE,
		GLYPH_REMOVE,
		GLYPH_CLEAR,
		GLYPH_SELECT_ALL,
		GLYPH_DESELECT_ALL,
	} from '$lib/glyphs.js';
	import Clear_Restore_Button from '$lib/Clear_Restore_Button.svelte';

	interface Props {
		socket: Socket;
		type: 'queued' | 'failed';
	}

	const {socket, type}: Props = $props();

	// Track selected messages for bulk actions
	const selected_messages: SvelteMap<string, boolean> = new SvelteMap();

	// Track expanded message details
	const expanded_messages: SvelteMap<string, boolean> = new SvelteMap();

	// Derive the message list based on type
	const messages = $derived.by(() => {
		if (type === 'queued') {
			return socket.message_queue;
		} else {
			const result = [];
			for (const [_id, message] of socket.failed_messages) {
				result.push(message);
			}
			return result;
		}
	});

	const messages_count = $derived(messages.length);
	const selected_count = $derived(selected_messages.size);
	const all_selected = $derived(selected_count === messages_count && messages_count > 0);

	// Message selection handlers
	const toggle_message_selection = (id: string, force?: boolean) => {
		const new_state = force !== undefined ? force : !selected_messages.has(id);
		if (new_state) {
			selected_messages.set(id, true);
		} else {
			selected_messages.delete(id);
		}
	};

	const select_all = () => {
		for (const message of messages) {
			selected_messages.set(message.id, true);
		}
	};

	const deselect_all = () => {
		selected_messages.clear();
	};

	// Message expansion handlers
	const toggle_expand = (id: string) => {
		if (expanded_messages.has(id)) {
			expanded_messages.delete(id);
		} else {
			expanded_messages.set(id, true);
		}
	};

	// Action handlers
	const retry_message = (message: Queued_Message) => {
		// For failed messages, we need to move them back to the queue
		if (type === 'failed') {
			socket.failed_messages.delete(message.id);
			socket.message_queue.push(message);
		}

		// For queued messages, we just need the socket to retry
		if (socket.connected) {
			socket.retry_queued_messages();
		}
	};

	const retry_selected = () => {
		if (type === 'failed') {
			for (const [id, _] of selected_messages) {
				const message = socket.failed_messages.get(id);
				if (message) {
					socket.failed_messages.delete(id);
					socket.message_queue.push(message);
				}
			}
		}

		if (socket.connected) {
			socket.retry_queued_messages();
		}

		// Clear selection after action
		deselect_all();
	};

	const remove_message = (message_id: string) => {
		if (type === 'queued') {
			socket.message_queue = socket.message_queue.filter((m) => m.id !== message_id);
		} else {
			socket.failed_messages.delete(message_id);
		}
		selected_messages.delete(message_id);
	};

	const remove_selected = () => {
		if (type === 'queued') {
			socket.message_queue = socket.message_queue.filter((m) => !selected_messages.has(m.id));
		} else {
			for (const [id, _] of selected_messages) {
				socket.failed_messages.delete(id);
			}
		}
		deselect_all();
	};

	const clear_all = () => {
		if (type === 'queued') {
			socket.message_queue = [];
		} else {
			socket.clear_failed_messages();
		}
		deselect_all();
	};
</script>

<div class="message_queue_container">
	<!-- Header with message count and action buttons -->
	<div class="flex justify_content_space_between align_items_center mb_sm">
		<span class="chip {type === 'queued' ? 'color_e' : 'color_c'}">
			{type === 'queued' ? 'queued' : 'failed'}: {messages_count}
		</span>

		<div class="flex gap_xs">
			{#if selected_count > 0}
				<div class="flex gap_xs align_items_center" transition:slide={{duration: 150}}>
					<span class="chip size_sm">{selected_count} selected</span>

					{#if type === 'queued' || (type === 'failed' && socket.connected)}
						<button
							type="button"
							class="icon_button plain size_sm"
							title="retry selected messages"
							onclick={retry_selected}
						>
							<Glyph_Icon icon={GLYPH_RETRY} />
						</button>
					{/if}

					<button
						type="button"
						class="icon_button plain size_sm color_c"
						title="remove selected messages"
						onclick={remove_selected}
					>
						<Glyph_Icon icon={GLYPH_DELETE} />
					</button>
				</div>
			{/if}

			<button
				type="button"
				class="icon_button plain size_sm"
				title={all_selected ? 'deselect all' : 'select all'}
				disabled={messages_count === 0}
				onclick={all_selected ? deselect_all : select_all}
			>
				<Glyph_Icon icon={all_selected ? GLYPH_DESELECT_ALL : GLYPH_SELECT_ALL} />
			</button>

			{#if messages_count > 0}
				<Clear_Restore_Button
					value="clear"
					onchange={clear_all}
					attrs={{class: 'size_sm', title: `clear all ${type} messages`}}
				>
					<Glyph_Icon icon={GLYPH_CLEAR} />
				</Clear_Restore_Button>
			{/if}
		</div>
	</div>

	<!-- Message list -->
	{#if messages_count > 0}
		<div class="message_list shadow_inset_top_sm">
			{#each messages as message (message.id)}
				{@const is_selected = selected_messages.has(message.id)}
				{@const is_expanded = expanded_messages.has(message.id)}

				<div
					class="message_item p_sm {is_selected ? 'selected bg_2' : ''} {messages.indexOf(message) >
					0
						? 'border_top border_solid border_color_3'
						: ''}"
				>
					<!-- Message header with ID, timestamp and actions -->
					<div class="flex gap_xs align_items_center mb_xs">
						<input
							type="checkbox"
							class="m_0"
							checked={is_selected}
							onclick={(e) => toggle_message_selection(message.id, e.currentTarget.checked)}
						/>

						<button
							type="button"
							class="plain font_mono flex_1 text_align_left size_sm p_0"
							onclick={() => toggle_expand(message.id)}
						>
							{message.id}
						</button>

						<span class="font_mono size_xs">{format(message.created, 'HH:mm:ss')}</span>

						<div class="flex gap_xs">
							{#if type === 'queued' || (type === 'failed' && socket.connected)}
								<button
									type="button"
									class="icon_button plain size_sm"
									title="retry message"
									onclick={() => retry_message(message)}
								>
									<Glyph_Icon icon={GLYPH_RETRY} />
								</button>
							{/if}

							<button
								type="button"
								class="icon_button plain"
								title="remove message"
								onclick={() => remove_message(message.id)}
							>
								<Glyph_Icon icon={GLYPH_REMOVE} />
							</button>
						</div>
					</div>

					<!-- Message details (expanded on click) -->
					{#if is_expanded}
						<div transition:slide={{duration: 150}}>
							{#if type === 'failed'}
								{@const failed_message = message as Failed_Message}
								<div class="flex justify_content_space_between size_xs mb_xs">
									<span>Failed at:</span>
									<span class="font_mono">{format(failed_message.failed_at, 'HH:mm:ss')}</span>
								</div>
								<div class="flex justify_content_space_between size_xs mb_xs">
									<span>Reason:</span>
									<span class="font_mono color_c">{failed_message.reason}</span>
								</div>
							{/if}

							<pre class="font_mono size_xs bg_2 p_xs radius_xs overflow_auto white_space_pre_wrap">
								{JSON.stringify(message.data, null, 2)}
							</pre>
						</div>
					{/if}
				</div>
			{/each}
		</div>
	{:else}
		<div class="p_md text_align_center border_dashed border_width_1 border_color_3 radius_xs bg_1">
			No {type} messages
		</div>
	{/if}
</div>

<style>
	.message_queue_container {
		margin-bottom: var(--size_md);
	}

	.message_list {
		max-height: 250px;
		overflow-y: auto;
		scrollbar-width: thin;
	}

	.message_item:hover {
		background-color: var(--fg_1);
	}

	.message_item.selected {
		border-left: 2px solid var(--color_a);
	}
</style>
