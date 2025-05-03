<script lang="ts">
	import {slide} from 'svelte/transition';
	import {format} from 'date-fns';
	import {SvelteMap} from 'svelte/reactivity';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';

	import type {Socket, Queued_Message, Failed_Message} from '$lib/socket.svelte.js';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_RETRY, GLYPH_REMOVE, GLYPH_INFO} from '$lib/glyphs.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Popover_Button from '$lib/Popover_Button.svelte';
	import {format_timestamp} from '$lib/time_helpers.js';

	interface Props {
		socket: Socket;
		type: 'queued' | 'failed';
	}

	const {socket, type}: Props = $props();

	// TODO show "ping the server" for both http and websocket transports

	// Track selected messages for bulk actions
	const selected_queued_messages: SvelteMap<string, boolean> = new SvelteMap();

	// Derive the message list based on type
	const queued_messages = $derived.by(() => {
		if (type === 'queued') {
			return socket.message_queue;
		} else {
			const result = [];
			for (const message of socket.failed_messages.values()) {
				result.push(message);
			}
			return result;
		}
	});

	const queued_messages_count = $derived(queued_messages.length);
	const selected_count = $derived(selected_queued_messages.size);
	const all_selected = $derived(
		selected_count === queued_messages_count && queued_messages_count > 0,
	);

	// Message selection handlers
	const toggle_queued_message_selection = (id: string, force?: boolean) => {
		const new_state = force !== undefined ? force : !selected_queued_messages.has(id);
		if (new_state) {
			selected_queued_messages.set(id, true);
		} else {
			selected_queued_messages.delete(id);
		}
	};

	const select_all = () => {
		for (const message of queued_messages) {
			selected_queued_messages.set(message.id, true);
		}
	};

	const deselect_all = () => {
		selected_queued_messages.clear();
	};

	// Action handlers
	const retry_queued_message = (queued_message: Queued_Message) => {
		// For failed messages, we need to move them back to the queue
		if (type === 'failed') {
			socket.failed_messages.delete(queued_message.id);
			socket.message_queue.push(queued_message);
		}

		// For queued messages, we just need the socket to retry
		if (socket.connected) {
			socket.retry_queued_messages();
		}
	};

	const retry_selected = () => {
		if (type === 'failed') {
			for (const id of selected_queued_messages.keys()) {
				const queued_message = socket.failed_messages.get(id);
				if (queued_message) {
					socket.failed_messages.delete(id);
					socket.message_queue.push(queued_message);
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
		selected_queued_messages.delete(message_id);
	};

	const remove_selected = () => {
		if (type === 'queued') {
			socket.message_queue = socket.message_queue.filter(
				(m) => !selected_queued_messages.has(m.id),
			);
		} else {
			for (const id of selected_queued_messages.keys()) {
				socket.failed_messages.delete(id);
			}
		}
		deselect_all();
	};
</script>

<div class="message_queue_container">
	<!-- Header with message count and action buttons -->
	<div class="flex justify_content_space_between align_items_center mb_sm">
		<span class="chip {type === 'queued' ? 'color_e' : 'color_c'}">
			{type}: {queued_messages_count}
		</span>

		<div class="flex gap_xs">
			{#if selected_count > 0}
				<div class="flex gap_xs align_items_center">
					<span class="chip font_size_sm">{selected_count} selected</span>

					{#if socket.connected}
						<button
							type="button"
							class="icon_button plain font_size_sm"
							title="retry selected messages"
							onclick={retry_selected}
							transition:slide
						>
							<Glyph glyph={GLYPH_RETRY} />
						</button>
					{/if}

					<Confirm_Button
						onconfirm={remove_selected}
						popover_button_attrs={{class: 'icon_button color_c bg_c_1 font_size_sm'}}
						attrs={{class: 'icon_button plain', title: 'remove selected messages'}}
					>
						<Glyph glyph={GLYPH_REMOVE} />
					</Confirm_Button>
				</div>
			{/if}

			<button
				type="button"
				class="plain font_size_sm"
				title="{all_selected ? 'deselect' : 'select'} all {type} messages"
				disabled={queued_messages_count === 0}
				onclick={all_selected ? deselect_all : select_all}
			>
				{all_selected ? 'deselect' : 'select'} all
			</button>
		</div>
	</div>

	<!-- Message list -->
	{#if queued_messages_count > 0}
		<div class="message_list shadow_inset_top_sm">
			{#each queued_messages as message (message.id)}
				{@const selected = selected_queued_messages.has(message.id)}
				{@const message_type = message.data?.type || 'unknown'}
				{@const message_data_serialized = JSON.stringify(message.data, null, 2)}
				<div
					class="message_item p_sm {selected ? 'selected bg_2' : ''} {queued_messages.indexOf(
						message,
					) > 0
						? 'border_top border_style_solid border_color_3'
						: ''}"
				>
					<!-- Message header with metadata and actions -->
					<div class="flex gap_xs align_items_center flex_wrap">
						<input
							type="checkbox"
							class="m_0 plain compact font_size_md"
							checked={selected}
							onclick={(e) => toggle_queued_message_selection(message.id, e.currentTarget.checked)}
						/>

						<!-- Message type information -->
						<div class="font_family_mono flex_1 flex flex_wrap align_items_center gap_xs">
							<small class="chip">{message_type}</small>

							<Copy_To_Clipboard
								text={message.id}
								attrs={{
									class: 'plain font_size_xs text_color_5',
									style: 'width: 120px;',
									title: 'copy message id to clipboard',
								}}
								copied_display_duration={0}
							>
								{#snippet children(copied)}
									{#if copied}
										<div><small class="font_size_xs">{message.id}</small></div>
									{:else}
										<div in:slide={{duration: 200}}>
											<small class="font_size_xs">{message.id}</small>
										</div>
									{/if}
								{/snippet}
							</Copy_To_Clipboard>
							<small class="chip">{message.data.message.type}</small>
							<Copy_To_Clipboard
								text={message.data.message.id}
								attrs={{
									class: 'plain font_size_xs text_color_5',
									style: 'width: 120px;',
									title: 'copy message id to clipboard',
								}}
								copied_display_duration={0}
							>
								{#snippet children(copied)}
									{#if copied}
										<div><small class="font_size_xs">{message.data.message.id}</small></div>
									{:else}
										<div in:slide={{duration: 200}}>
											<small class="font_size_xs">{message.data.message.id}</small>
										</div>
									{/if}
								{/snippet}
							</Copy_To_Clipboard>
						</div>

						<span class="font_size_sm">{format_timestamp(message.created)}</span>

						<div class="flex gap_xs">
							<!-- Message details in popover -->
							<Popover_Button
								position="left"
								attrs={{class: 'icon_button plain font_size_sm', title: 'view message details'}}
							>
								<Glyph glyph={GLYPH_INFO} size="var(--font_size_lg)" />
								{#snippet popover_content(popover)}
									<div
										class="p_md overflow_auto bg shadow_bottom_md"
										style:max-height="400px"
										style:max-width="500px"
										style:min-width="300px"
										style:border="1px solid var(--border_color_3)"
										style:border-radius="var(--border_radius_xs)"
										style:z-index="100"
									>
										<div class="flex justify_content_space_between mb_xs">
											<h3 class="mt_xs">message details</h3>
											<button
												type="button"
												class="icon_button plain font_size_xs"
												onclick={() => popover.hide()}
											>
												✕
											</button>
										</div>
										<pre
											class="fg_1 border_radius_xs border_width border_style border_color_2 font_family_mono font_size_xs white_space_pre_wrap word_break_break_word p_md">{message_data_serialized}</pre>
										<Copy_To_Clipboard text={message_data_serialized} />
									</div>
								{/snippet}
							</Popover_Button>

							<!-- eslint-disable-next-line @typescript-eslint/no-unnecessary-condition -->
							{#if type === 'queued' || (type === 'failed' && socket.connected)}
								<button
									type="button"
									class="icon_button plain font_size_sm"
									title="retry message"
									onclick={() => retry_queued_message(message)}
								>
									<Glyph glyph={GLYPH_RETRY} />
								</button>
							{/if}

							<Confirm_Button
								onconfirm={() => remove_message(message.id)}
								position="center"
								popover_button_attrs={{class: 'icon_button color_c bg_c_1 font_size_sm'}}
								attrs={{class: 'icon_button plain font_size_sm', title: 'remove message'}}
							>
								<Glyph glyph={GLYPH_REMOVE} />
							</Confirm_Button>
						</div>
					</div>

					<!-- Failed message details -->
					{#if type === 'failed'}
						{@const failed_message = message as Failed_Message}
						<div class="flex flex_column font_size_xs mt_xs">
							<div class="flex justify_content_space_between mb_xs">
								<span>Failed at:</span>
								<span class="font_family_mono">{format(failed_message.failed, 'HH:mm:ss')}</span>
							</div>
							<div class="flex justify_content_space_between">
								<span>Reason:</span>
								<span class="font_family_mono color_c">{failed_message.reason}</span>
							</div>
						</div>
					{/if}
				</div>
			{/each}
		</div>
	{:else}
		<div
			class="p_md text_align_center border_style_dashed border_width_1 border_color_3 border_radius_xs bg_1"
		>
			No {type} messages
		</div>
	{/if}
</div>

<style>
	.message_queue_container {
		margin-bottom: var(--font_size_md);
	}

	.message_list {
		max-height: 250px;
		overflow: auto;
		scrollbar-width: thin;
	}

	.message_item:hover {
		background-color: var(--fg_1);
	}

	.message_item.selected {
		border-left: 2px solid var(--color_a);
	}
</style>
