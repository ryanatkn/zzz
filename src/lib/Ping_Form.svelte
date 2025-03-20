<script lang="ts">
	import {slide} from 'svelte/transition';
	import type {Snippet} from 'svelte';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_DIRECTION_CLIENT, GLYPH_DIRECTION_SERVER} from '$lib/glyphs.js';
	import {PING_HISTORY_MAX} from '$lib/capabilities.svelte.js';

	interface Props {
		children?: Snippet;
	}

	const {children}: Props = $props();

	const zzz = zzz_context.get();
	const {capabilities} = zzz;

	// Use ping data from capabilities
	const pings = $derived(capabilities.pings);

	// Get pending ping count directly from capabilities
	const {has_pending_pings, pending_ping_count} = $derived(capabilities);

	// Calculate placeholders to maintain consistent spacing
	const remaining_placeholders = $derived(Math.max(0, PING_HISTORY_MAX - pings.length));
</script>

<div class="column align_items_start gap_sm">
	<div>
		<button
			type="button"
			title="ping the server"
			onclick={() => zzz.capabilities.send_ping()}
			class="flex_1"
			class:color_d={has_pending_pings}
		>
			{#if children}{@render children()}{:else}⚞{/if}
			<div class="size_lg font_weight_400 pl_sm">
				ping the server
				{#if has_pending_pings}
					<span class="font_mono size_sm ml_xs">(pending: {pending_ping_count})</span>
					<span class="ml_xs"><Pending_Animation /></span>
				{/if}
			</div>
		</button>
	</div>

	<ul
		class="unstyled overflow_auto scrollbar_width_thin column panel p_md pb_0 mb_0 shadow_inset_top_xs"
		style:height="150px"
		style:min-height="150px"
	>
		{#each pings as ping (ping.ping_id)}
			<li transition:slide>
				{@render ping_item(ping.round_trip_time)}
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
