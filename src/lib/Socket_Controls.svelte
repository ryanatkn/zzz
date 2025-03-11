<script lang="ts">
	import {slide} from 'svelte/transition';
	import {format, formatDuration, intervalToDuration} from 'date-fns';
	import {BROWSER, DEV} from 'esm-env';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {PUBLIC_SERVER_HOSTNAME, PUBLIC_SERVER_PORT} from '$env/static/public';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Socket} from '$lib/socket.svelte.js';
	import Clear_Restore_Button from '$lib/Clear_Restore_Button.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {GLYPH_CONNECT, GLYPH_CANCEL, GLYPH_DISCONNECT, GLYPH_RESET} from '$lib/glyphs.js';
	import {format_ms_to_readable} from '$lib/time_helpers.js';
	import {
		DEFAULT_HEARTBEAT_INTERVAL,
		DEFAULT_RECONNECT_DELAY,
		DEFAULT_RECONNECT_DELAY_MAX,
	} from '$lib/socket_helpers.js';

	// TODO config - support multiple connections probably
	const DEFAULT_WS_URL = `${DEV ? 'ws' : 'wss'}://${PUBLIC_SERVER_HOSTNAME}:${PUBLIC_SERVER_PORT}/ws`;

	const pid = $props.id();

	// TODO BLOCK extract a component from here to show the queued messages and have controls to remove them (and bulk actions) - use Messages_List for inspiration but make a new component that takes a socket prop

	interface Props {
		socket?: Socket;
	}

	const {socket: socket_prop}: Props = $props();

	// Get socket from props or context
	const zzz = zzz_context.get();
	const socket = $derived(socket_prop || zzz.socket);

	// Show/hide sections
	let show_queued_messages = $state(false);
	let show_failed_messages = $state(false);

	// Track URL state for reset/undo functionality
	let previous_url = $state('');
	let has_undo_state = $state(false);

	// Reset the socket configuration to defaults
	const reset_to_defaults = () => {
		socket.heartbeat_interval = DEFAULT_HEARTBEAT_INTERVAL;
		socket.reconnect_delay = DEFAULT_RECONNECT_DELAY;
		socket.reconnect_delay_max = DEFAULT_RECONNECT_DELAY_MAX;
	};

	const failed_messages_as_array = $derived.by(() => {
		const result = [];
		for (const [_id, message] of socket.failed_messages) {
			result.push(message);
		}
		return result;
	});

	const format_timestamp = (timestamp: number | null) =>
		timestamp ? format(timestamp, 'h:mm a') : '-';

	// Reset the URL to the default value
	const reset_url = () => {
		if (socket.url_input !== DEFAULT_WS_URL) {
			previous_url = socket.url_input;
			has_undo_state = true;
			socket.url_input = DEFAULT_WS_URL;
		}
	};

	// Restore the previous URL
	const restore_previous_url = () => {
		if (previous_url) {
			socket.url_input = previous_url;
			previous_url = '';
			has_undo_state = false;
		}
	};

	// Check if the current URL is the default
	const is_default_url = $derived(socket.url_input === DEFAULT_WS_URL);

	// Handle the URL reset button click
	const handle_reset_url_click = () => {
		if (has_undo_state) {
			restore_previous_url();
		} else {
			reset_url();
		}
	};

	// Handle cancel reconnect button click
	const handle_cancel_reconnect = () => {
		socket.auto_reconnect = false;
		socket.cancel_reconnect();
	};
</script>

<!-- Main control section with flex layout for wide screens -->
<div class="flex flex_wrap gap_xl mb_md">
	<!-- Left column: Connection status and controls -->
	<div class="flex_1 min_width_sm">
		<!-- Status display -->

		<!-- URL input and connect/disconnect -->
		<div class="flex flex_column gap_sm mb_sm">
			<div
				class="chip plain flex_1 size_xl flex_column align_items_start"
				style:display="flex !important"
				style:align-items="flex-start"
				style:font-weight="400 !important"
				class:color_b={socket.status === 'success'}
				class:color_c={socket.status === 'failure'}
				class:color_d={socket.status === 'pending'}
				class:color_e={socket.status === 'initial'}
			>
				<div class="column justify_content_center gap_xs pl_md" style:min-height="80px">
					websocket {socket.connected
						? 'connected'
						: socket.status === 'pending'
							? 'connecting'
							: 'disconnected'}
					<small class="font_mono">{socket.url || ' '}</small>
				</div>
			</div>

			<fieldset class="mb_0">
				<div class="flex gap_xs mb_sm">
					<input
						type="text"
						class="plain flex_1"
						placeholder="websocket url, ws:// or wss://"
						bind:value={socket.url_input}
					/>
					<button
						type="button"
						class="icon_button plain"
						title={has_undo_state ? `undo to ${previous_url}` : 'reset url to default'}
						disabled={is_default_url && !has_undo_state}
						onclick={handle_reset_url_click}
					>
						<div class:flip_x={has_undo_state}>{GLYPH_RESET}</div>
					</button>
				</div>

				<div class="flex justify_content_space_between gap_md">
					<button
						type="button"
						class="flex_1 justify_content_start"
						class:color_d={socket.connected &&
							socket.url !== socket.url_input &&
							socket.url_input !== ''}
						class:color_a={!socket.connected && socket.status !== 'pending'}
						disabled={socket.status === 'pending' || (!socket.connected && !socket.url_input)}
						onclick={() => {
							if (socket.connected) {
								if (socket.url !== socket.url_input && socket.url_input !== '') {
									socket.disconnect();
									socket.connect();
								} else {
									socket.disconnect();
								}
							} else if (socket.status === 'failure' && socket.url) {
								socket.connect();
							} else if (socket.url_input) {
								socket.connect();
							}
						}}
					>
						<Glyph_Icon
							icon={socket.connected && socket.url === socket.url_input
								? GLYPH_DISCONNECT
								: GLYPH_CONNECT}
							size="var(--size_xl)"
						/>
						<span class="size_lg font_weight_400 ml_md">
							{#if !BROWSER}
								<div class="inline_flex align_items_end">
									loading <div class="relative" style:top="5px"><Pending_Animation /></div>
								</div>
							{:else if socket.connected}
								{socket.url !== socket.url_input && socket.url_input !== ''
									? 'reconnect websocket'
									: 'disconnect websocket'}
							{:else if socket.status === 'pending'}
								<div class="inline_flex align_items_end">
									connecting <div class="relative" style:top="5px"><Pending_Animation /></div>
								</div>
							{:else}
								connect websocket
							{/if}
						</span>
					</button>
				</div>
			</fieldset>

			<div>
				<div class="column align_items_start">
					<label class="flex gap_xs align_items_center">
						<input
							type="checkbox"
							class="compact size_sm"
							bind:checked={socket.auto_reconnect}
							onclick={() => {
								// If turning off auto-reconnect, cancel any pending reconnects
								if (socket.auto_reconnect && socket.reconnect_timeout !== null) {
									socket.cancel_reconnect();
								}
							}}
						/>
						<small>auto-reconnect</small>
					</label>
				</div>

				{#if socket.status === 'failure' && socket.reconnect_timeout !== null}
					<div class="row mt_sm gap_xs" transition:slide>
						<button
							type="button"
							class="color_d size_xl icon_button plain"
							title="cancel reconnection attempt"
							onclick={handle_cancel_reconnect}
						>
							{GLYPH_CANCEL}
						</button>
						<div class="w_100 radius_xs relative overflow_hidden bg_d_1" style:height="24px">
							<div class="absolute w_100 h_100 row px_lg font_mono" style:z-index="2">
								reconnecting in...
							</div>
							{#key socket.current_reconnect_delay}
								<div
									class="progress_fill bg_d_2"
									style:animation-duration="{socket.current_reconnect_delay}ms"
								></div>
							{/key}
						</div>
					</div>
				{/if}
			</div>
		</div>
	</div>

	<!-- Right column: Config sliders -->
	<div class="flex_1 min_width_sm p_sm radius_xs">
		<div class="flex flex_column gap_sm">
			<div class="row">
				<label
					for="heartbeat_interval_{pid}"
					class="block white_space_nowrap mb_xs"
					style:width="170px"
					style:min-width="170px"
				>
					<div>heartbeat interval</div>
					<small>{format_ms_to_readable(socket.heartbeat_interval)}</small>
				</label>
				<div class="flex gap_xs">
					<input
						type="range"
						min="10000"
						max="600000"
						step="10000"
						class="flex_1 compact plain"
						bind:value={socket.heartbeat_interval}
					/>
					<input
						id="heartbeat_interval_{pid}"
						type="text"
						class="input_xs compact plain"
						bind:value={socket.heartbeat_interval}
					/>
				</div>
			</div>

			<div class="row">
				<label
					for="reconnect_delay_{pid}"
					class="block white_space_nowrap mb_xs"
					style:width="170px"
					style:min-width="170px"
				>
					<div>reconnect delay</div>
					<small>{format_ms_to_readable(socket.reconnect_delay, 1)}</small>
				</label>
				<div class="flex gap_xs">
					<input
						type="range"
						min="100"
						max="10000"
						step="100"
						class="flex_1 compact plain"
						bind:value={socket.reconnect_delay}
					/>
					<input
						id="reconnect_delay_{pid}"
						type="text"
						class="input_xs compact plain"
						bind:value={socket.reconnect_delay}
					/>
				</div>
			</div>

			<div class="row">
				<label
					for="reconnect_delay_max_{pid}"
					class="block white_space_nowrap mb_xs"
					style:width="170px"
					style:min-width="170px"
				>
					<div>max reconnect delay</div>
					<small>{format_ms_to_readable(socket.reconnect_delay_max)}</small>
				</label>
				<div class="flex gap_xs">
					<input
						type="range"
						min="1000"
						max="300000"
						step="1000"
						class="flex_1 compact plain"
						bind:value={socket.reconnect_delay_max}
					/>
					<input
						id="reconnect_delay_max_{pid}"
						type="text"
						class="input_xs compact plain"
						bind:value={socket.reconnect_delay_max}
					/>
				</div>
			</div>

			<div class="flex justify_content_end">
				<Confirm_Button
					onconfirm={reset_to_defaults}
					attrs={{class: 'plain size_sm compact font_weight_600'}}
				>
					reset to defaults

					{#snippet popover_content(popover)}
						<button
							type="button"
							class="color_c icon_button bg_c_1"
							title="confirm reset settings"
							onclick={() => {
								reset_to_defaults();
								popover.hide();
							}}
						>
							<div>{GLYPH_RESET}</div>
						</button>
					{/snippet}
				</Confirm_Button>
			</div>
		</div>
	</div>
</div>

<div class="flex gap_xl5">
	<!-- Connection Stats with retries included -->
	<div class="width_xs mt_md border_top pt_md">
		<div class="flex flex_column gap_sm mb_sm">
			{#if socket.reconnect_count > 0}
				<div class="flex justify_content_space_between" transition:slide>
					<small>reconnection attempts:</small>
					<span class="font_weight_600">{socket.reconnect_count}</span>
				</div>
				<div class="flex justify_content_space_between" transition:slide>
					<small>current reconnect delay:</small>
					<span class="font_weight_600">{socket.current_reconnect_delay}</span>
				</div>
			{/if}

			<div class="flex justify_content_space_between" transition:slide>
				<small>connected for:</small>
				<small>
					{socket.connection_duration_rounded
						? formatDuration(
								intervalToDuration({start: 0, end: socket.connection_duration_rounded}),
							)
						: '-'}
				</small>
			</div>
			<div class="flex justify_content_space_between">
				<small>connected:</small>
				<small>{format_timestamp(socket.last_connect_time)}</small>
			</div>
			<div class="flex justify_content_space_between">
				<small>last send:</small>
				<small>{format_timestamp(socket.last_send_time)}</small>
			</div>
			<div class="flex justify_content_space_between">
				<small>last receive:</small>
				<small>{format_timestamp(socket.last_receive_time)}</small>
			</div>
		</div>
	</div>
</div>

<!-- Message Queue Stats -->
{#if socket.queued_message_count > 0 || socket.failed_message_count > 0}
	<div class="mt_md border_top pt_md" transition:slide>
		<h4 class="mt_0 mb_sm">message queue</h4>

		<div class="flex flex_column gap_md mb_sm">
			{#if socket.queued_message_count > 0}
				<div>
					<div class="flex justify_content_space_between mb_xs">
						<div class="flex align_items_center gap_xs">
							<span class="chip color_b">Queued: {socket.queued_message_count}</span>
							<button
								type="button"
								class="plain size_sm"
								onclick={() => (show_queued_messages = !show_queued_messages)}
							>
								{show_queued_messages ? 'hide' : 'show'} messages
							</button>
						</div>

						{#if socket.connected}
							<button
								type="button"
								class="color_a size_sm"
								onclick={() => socket.retry_queued_messages()}
							>
								retry now
							</button>
						{/if}
					</div>

					{#if show_queued_messages}
						<div
							transition:slide
							class="border_width_1 border_solid border_color_4 radius_xs my_xs"
						>
							<div class="p_sm">
								<h5 class="mt_0 mb_xs size_md">queued messages</h5>
							</div>
							<div class="max_height_sm overflow_auto">
								{#each socket.message_queue as message (message.id)}
									<div class="p_sm border_top border_solid border_color_3">
										<div class="flex justify_content_space_between mb_xs">
											<small class="font_mono">{message.id}</small>
											<small>{format(message.created, 'HH:mm:ss')}</small>
										</div>
										<pre
											class="font_mono size_sm bg_2 p_xs radius_xs overflow_auto">{JSON.stringify(
												message.data,
												null,
												2,
											)}</pre>
									</div>
								{:else}
									<p class="p_sm">no queued messages</p>
								{/each}
							</div>
						</div>
					{/if}
				</div>
			{/if}

			{#if socket.failed_message_count > 0}
				<div>
					<div class="flex justify_content_space_between mb_xs">
						<div class="flex align_items_center gap_xs">
							<span class="chip color_c">Failed: {socket.failed_message_count}</span>
							<button
								type="button"
								class="plain size_sm"
								onclick={() => (show_failed_messages = !show_failed_messages)}
							>
								{show_failed_messages ? 'hide' : 'show'} messages
							</button>
						</div>

						<Clear_Restore_Button
							value={socket.failed_message_count > 0 ? 'clear' : ''}
							onchange={() => socket.clear_failed_messages()}
							attrs={{class: 'size_sm'}}
						>
							clear failed
						</Clear_Restore_Button>
					</div>

					{#if show_failed_messages}
						<div
							transition:slide
							class="border_width_1 border_solid border_color_4 radius_xs my_xs"
						>
							<div class="p_sm">
								<h5 class="mt_0 mb_xs size_md">failed messages</h5>
							</div>
							<div class="max_height_sm overflow_auto">
								{#each failed_messages_as_array as message (message.id)}
									<div class="p_sm border_top border_solid border_color_3">
										<div class="flex justify_content_space_between mb_xs">
											<small class="font_mono">{message.id}</small>
											<small>{format(message.created, 'HH:mm:ss')}</small>
										</div>
										<div class="flex justify_content_space_between mb_xs">
											<span>failed at:</span>
											<span>{format(message.failed_at, 'HH:mm:ss')}</span>
										</div>
										<div class="flex justify_content_space_between mb_xs">
											<span>reason:</span>
											<span class="color_c">{message.reason}</span>
										</div>
										<pre
											class="font_mono size_sm bg_2 p_xs radius_xs overflow_auto">{JSON.stringify(
												message.data,
												null,
												2,
											)}</pre>
									</div>
								{:else}
									<p class="p_sm">no failed messages</p>
								{/each}
							</div>
						</div>
					{/if}
				</div>
			{/if}
		</div>
	</div>
{/if}

<style>
	@keyframes progress-animation {
		0% {
			transform: translateX(-100%);
		}
		100% {
			transform: translateX(0);
		}
	}

	.progress_fill {
		position: absolute;
		width: 100%;
		height: 100%;
		transform: translateX(-100%);
		animation: progress-animation linear forwards;
		z-index: 1;
	}
</style>
