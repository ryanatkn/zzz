<script lang="ts">
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {slide} from 'svelte/transition';
	import type {Snippet} from 'svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_DIRECTION_CLIENT, GLYPH_DIRECTION_SERVER} from '$lib/glyphs.js';
	import type {Uuid} from '$lib/zod_helpers.js';

	interface Props {
		children?: Snippet;
	}

	const {children}: Props = $props();

	const zzz = zzz_context.get();

	const HISTORY_SIZE = 6;

	const pongs = $derived(zzz.messages.items.get_derived('latest_pongs'));

	interface Display_Item {
		pong_id?: Uuid;
		ping_id?: Uuid | undefined;
		server_time?: number | undefined;
		round_trip_time?: number | undefined;
	}
	[];

	// Create display items from pongs
	const display_items: Array<Display_Item> = $derived.by(() => {
		return pongs
			.filter((pong) => pong.response_time !== undefined)
			.map((pong) => {
				// Get the corresponding ping message
				const ping = zzz.messages.items.by_id.get(pong.ping_id!);

				return {
					pong_id: pong.id,
					ping_id: pong.ping_id,
					server_time: pong.response_time,
					// Total round trip time - from ping send to pong receive
					round_trip_time: ping ? pong.received_time - ping.received_time : undefined,
				};
			});
	});
	$inspect('[Ping_Form] display_items', display_items);

	// Calculate placeholders to maintain consistent spacing
	const remaining_placeholders = $derived(Math.max(0, HISTORY_SIZE - display_items.length));
</script>

<div class="column align_items_start gap_sm">
	<div>
		<button type="button" title="ping the server" onclick={() => zzz.send_ping()} class="flex_1">
			{#if children}{@render children()}{:else}⚞{/if}
			<div class="size_lg font_weight_400 pl_sm">ping the server</div>
		</button>
	</div>

	<ul
		class="unstyled overflow_auto scrollbar_width_thin column panel p_md pb_0 mb_0 shadow_inset_top_xs"
		style:height="150px"
		style:min-height="150px"
	>
		{#each display_items as item (item.pong_id)}
			<li transition:slide>
				{#if item.round_trip_time !== undefined}
					{@render ping_item(item.round_trip_time)}
				{:else}
					<Pending_Animation />
				{/if}
			</li>
		{/each}
		{#each {length: remaining_placeholders} as _, i (i)}
			<li class="placeholder" transition:slide>
				<div style:visibility="hidden">{@render ping_item(1)}</div>
			</li>
		{/each}
	</ul>
</div>

{#snippet ping_item(round_trip_time: number)}
	{GLYPH_DIRECTION_CLIENT}{GLYPH_DIRECTION_SERVER}
	<span class="font_mono">{Math.round(round_trip_time)}ms</span>
{/snippet}
