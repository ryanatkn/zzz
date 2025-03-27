<script lang="ts">
	import {slide} from 'svelte/transition';
	import {formatDuration, intervalToDuration} from 'date-fns';
	import {BROWSER} from 'esm-env';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {PUBLIC_WEBSOCKET_URL} from '$env/static/public';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Socket} from '$lib/socket.svelte.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {
		GLYPH_CONNECT,
		GLYPH_CANCEL,
		GLYPH_DISCONNECT,
		GLYPH_RESET,
		GLYPH_PLACEHOLDER,
	} from '$lib/glyphs.js';
	import {format_ms_to_readable, format_timestamp} from '$lib/time_helpers.js';
	import {
		DEFAULT_HEARTBEAT_INTERVAL,
		DEFAULT_RECONNECT_DELAY,
		DEFAULT_RECONNECT_DELAY_MAX,
	} from '$lib/socket_helpers.js';
	import Socket_Message_Queue from '$lib/Socket_Message_Queue.svelte';

	const pid = $props.id();

	interface Props {
		socket?: Socket | undefined;
	}

	const {socket: socket_prop}: Props = $props();

	// Get socket from props or context
	const zzz = zzz_context.get();
	const socket = $derived(socket_prop || zzz.socket);
	const {capabilities} = zzz;

	// Track URL state for reset/undo functionality
	let previous_url = $state('');
	let has_undo_state = $state(false);

	// Reset the socket configuration to defaults
	const reset_to_defaults = () => {
		socket.heartbeat_interval = DEFAULT_HEARTBEAT_INTERVAL;
		socket.reconnect_delay = DEFAULT_RECONNECT_DELAY;
		socket.reconnect_delay_max = DEFAULT_RECONNECT_DELAY_MAX;
	};

	// Reset the URL to the default value
	const reset_url = () => {
		if (socket.url_input !== PUBLIC_WEBSOCKET_URL) {
			previous_url = socket.url_input;
			has_undo_state = true;
			socket.url_input = PUBLIC_WEBSOCKET_URL;
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
	const is_default_url = $derived(socket.url_input === PUBLIC_WEBSOCKET_URL); // TODO maybe move to `socket.url_input_is_default`
</script>

<!-- Main control section with flex layout for wide screens -->
<div class="flex flex_wrap gap_xl mb_md">
	<!-- Left column: Connection status and controls -->
	<div class="flex_1 min_width_sm">
		<!-- Status display -->

		<!-- URL input and connect/disconnect -->
		<div class="flex flex_column gap_sm mb_sm">
			<div
				class="chip plain flex_1 size_xl px_xl flex_column"
				style:display="flex !important"
				style:align-items="flex-start !important"
				style:font-weight="400 !important"
				class:color_b={capabilities.websocket.status === 'success' && socket.connected}
				class:color_c={capabilities.websocket.status === 'failure'}
				class:color_d={capabilities.websocket.status === 'pending'}
				class:color_e={capabilities.websocket.status === 'initial'}
				class:color_h={capabilities.websocket.status === 'success' && !socket.connected}
			>
				<div class="column justify_content_center gap_xs" style:min-height="80px">
					websocket {socket.connected
						? 'connected'
						: socket.status === 'pending'
							? 'connecting'
							: 'disconnected'}
					{#if capabilities.has_pending_pings}
						<span class="font_mono"
							>(pending pings: {capabilities.pending_ping_count}) <Pending_Animation /></span
						>
					{/if}
					<small class="font_mono"
						>{#if socket.url}{socket.url}{:else}&nbsp;{/if}</small
					>
				</div>
			</div>

			<fieldset class="mb_0">
				<div class="flex gap_xs mb_sm">
					<input
						type="text"
						class="plain flex_1"
						placeholder="{GLYPH_PLACEHOLDER} websocket url, ws:// or wss://"
						bind:value={socket.url_input}
					/>
					<button
						type="button"
						class="icon_button plain"
						title={has_undo_state ? `undo to ${previous_url}` : 'reset url to default'}
						disabled={is_default_url && !has_undo_state}
						onclick={() => {
							if (has_undo_state) {
								restore_previous_url();
							} else {
								reset_url();
							}
						}}
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
						<Glyph
							icon={socket.connected && socket.url === socket.url_input
								? GLYPH_DISCONNECT
								: GLYPH_CONNECT}
							size="var(--size_xl)"
						/>
						<span class="size_lg font_weight_400 ml_md">
							{#if !BROWSER}
								<div class="inline_flex align_items_end">
									loading <div class="relative"><Pending_Animation /></div>
								</div>
							{:else if socket.connected}
								{socket.url !== socket.url_input && socket.url_input !== ''
									? 'reconnect websocket'
									: 'disconnect websocket'}
							{:else if socket.status === 'pending'}
								<div class="inline_flex align_items_end">
									connecting <div class="relative"><Pending_Animation /></div>
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
							bind:checked={
								() => socket.auto_reconnect,
								(v) => {
									// If turning off auto-reconnect, cancel any pending reconnects
									if (!v && socket.reconnect_timeout !== null) {
										socket.cancel_reconnect();
									} else if (v && !socket.connected && socket.status !== 'pending') {
										// If turning on auto-reconnect and we're disconnected, try to connect immediately
										socket.connect();
									}
									socket.auto_reconnect = v;
								}
							}
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
							onclick={() => {
								socket.cancel_reconnect();
							}}
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

			<div class="flex justify_content_space_between">
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
				<Socket_Message_Queue {socket} type="queued" />
			{/if}

			{#if socket.failed_message_count > 0}
				<Socket_Message_Queue {socket} type="failed" />
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
