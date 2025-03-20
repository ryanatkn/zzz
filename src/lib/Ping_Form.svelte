<script lang="ts">
	import {slide} from 'svelte/transition';
	import type {Snippet} from 'svelte';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_DIRECTION_CLIENT, GLYPH_DIRECTION_SERVER} from '$lib/glyphs.js';
	import {PING_HISTORY_MAX, type Ping_Data} from '$lib/capabilities.svelte.js';

	interface Props {
		children?: Snippet;
	}

	const {children}: Props = $props();

	const zzz = zzz_context.get();
	const {capabilities} = zzz;

	// Calculate placeholders to maintain consistent spacing
	const remaining_placeholders = $derived(
		Math.max(0, PING_HISTORY_MAX - capabilities.pings.length),
	);
</script>

<div class="column align_items_start gap_sm">
	<div>
		<button
			type="button"
			title="ping the server"
			onclick={() => capabilities.send_ping()}
			class="flex_1"
		>
			{#if children}{@render children()}{:else}⚞{/if}
			<div class="size_lg font_weight_400 pl_sm">ping the server</div>
		</button>
	</div>

	<ul
		class="unstyled overflow_auto scrollbar_width_thin column panel p_md pb_0 mb_0 shadow_inset_top_xs"
		style:height="150px"
		style:min-height="150px"
	>
		<!-- Display all pings, both pending and completed -->
		{#each capabilities.pings as ping (ping.ping_id)}
			<li transition:slide>
				{@render ping_item(ping)}
			</li>
		{/each}

		<!-- Empty placeholders to maintain consistent size -->
		{#each {length: remaining_placeholders} as _, i (i)}
			<li transition:slide>
				<div style:visibility="hidden">
					{@render ping_item({
						ping_id: (i + ' placeholder') as any,
						completed: true,
						sent_time: 0,
						received_time: 0,
						round_trip_time: 0,
					})}
				</div>
			</li>
		{/each}
	</ul>
</div>

{#snippet ping_item(ping: Ping_Data)}
	{GLYPH_DIRECTION_CLIENT}<span class:fade_3={!ping.completed}>{GLYPH_DIRECTION_SERVER}</span>
	{#if !ping.completed}
		<span class="font_mono">
			<Pending_Animation attrs={{style: 'display: inline-flex !important'}} />
		</span>
	{:else}
		<span class="font_mono">{Math.round(ping.round_trip_time ?? 0)}ms</span>
	{/if}
{/snippet}
