<script lang="ts">
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {slide} from 'svelte/transition';
	import type {Snippet} from 'svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_DIRECTION_CLIENT, GLYPH_DIRECTION_SERVER} from '$lib/glyphs.js';

	interface Props {
		children?: Snippet;
	}

	const {children}: Props = $props();

	const zzz = zzz_context.get();

	// Fixed history size
	const HISTORY_SIZE = 6;

	// Use the Messages collections directly with filter and limit
	const pongs = $derived(zzz.messages.by_type.get('pong')?.slice(-HISTORY_SIZE));
	const pings = $derived(
		pongs?.map((p) => zzz.messages.by_id.get(p.ping_id!)).filter((p) => !!p) ?? [],
	);

	// Map of ping IDs to response times (use SvelteMap from zzz for reactivity)
	const ping_response_times = $derived(zzz.ping_elapsed);

	const displayed_pings = $derived(pings.slice().reverse());
	const remaining_placeholders = $derived(Math.max(0, HISTORY_SIZE - pings.length));

	// TODO probably use this and the markup, but make it look better (maybe positioned to the right of the pings)
	// Calculate ping times for display
	// const ping_times = $derived.by(() => {
	// 	const times: Array<number> = [];
	// 	for (const time of zzz.ping_elapsed.values()) {
	// 		times.push(time);
	// 	}
	// 	return times.sort((a, b) => a - b);
	// });

	// const ping_avg = $derived(
	// 	ping_times.length
	// 		? Math.round(ping_times.reduce((sum, time) => sum + time, 0) / ping_times.length)
	// 		: null,
	// );

	// const ping_min = $derived(ping_times.length ? Math.round(ping_times[0]) : null);

	// const ping_max = $derived(
	// 	ping_times.length ? Math.round(ping_times[ping_times.length - 1]) : null,
	// );
</script>

<div class="column align_items_start gap_sm">
	<div>
		<button type="button" title="ping the server" onclick={() => zzz.send_ping()} class="flex_1"
			>{#if children}{@render children()}{:else}⚞{/if}
			<div class="size_lg font_weight_400 pl_sm">ping the server</div>
		</button>
	</div>

	<!-- Hardcode the height to prevent animated content causing weird reflow -->
	<ul
		class="unstyled overflow_hidden scrollbar_width_thin column panel p_md mb_0"
		style:height="162px"
	>
		{#each displayed_pings as ping (ping.id)}
			{@const response_time = ping_response_times.get(ping.id)}
			<li transition:slide>
				{#if response_time !== undefined}
					{@render ping_item(response_time)}
				{:else}
					<Pending_Animation />
				{/if}
			</li>
		{/each}
		{#each {length: remaining_placeholders} as _}
			<li class="placeholder" transition:slide>
				<div style:visibility="hidden">{@render ping_item(1)}</div>
			</li>
		{/each}
	</ul>

	<!-- {#if ping_avg !== null}
		<div class="p_xs bg_2 radius_xs">
			<div class="size_sm mb_xs">ping latency:</div>
			<div class="font_weight_600 size_md">{ping_avg}ms</div>
			<div class="size_sm">
				<span>min:</span>
				{ping_min}ms /
				<span>max:</span>
				{ping_max}ms
			</div>
		</div>
	{/if} -->
</div>

{#snippet ping_item(response_time: number)}
	{GLYPH_DIRECTION_CLIENT}{GLYPH_DIRECTION_SERVER}
	<span class="font_mono">{Math.round(response_time)}ms</span>
{/snippet}
