<script lang="ts">
	import {slide} from 'svelte/transition';
	import type {Snippet} from 'svelte';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import {zzz_context} from '$lib/frontend.svelte.js';
	import {GLYPH_ACTION_TYPE_REQUEST_RESPONSE} from '$lib/glyphs.js';
	import {PING_HISTORY_MAX, type Ping_Data} from '$lib/capabilities.svelte.js';
	import Glyph from '$lib/Glyph.svelte';

	interface Props {
		children?: Snippet | undefined;
	}

	const {children}: Props = $props();

	const app = zzz_context.get();
	const {capabilities} = app;

	// Calculate placeholders to maintain consistent spacing
	const remaining_placeholders = $derived(
		Math.max(0, PING_HISTORY_MAX - capabilities.pings.length),
	);

	// TODO consider multiple buttons for each transport, so we can compare latency
</script>

<div class="column align_items_start gap_sm">
	<div>
		<button type="button" title="ping the server" onclick={() => app.api.ping()} class="flex_1">
			{#if children}{@render children()}{:else}⚞{/if}
			<div class="font_size_lg font_weight_400 pl_sm">ping the server</div>
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
	<Glyph
		glyph={GLYPH_ACTION_TYPE_REQUEST_RESPONSE}
		attrs={{class: ping.completed ? '' : 'opacity_40'}}
	/>
	{#if !ping.completed}
		<span class="font_family_mono">
			<Pending_Animation inline />
		</span>
	{:else}
		<span class="font_family_mono">{Math.round(ping.round_trip_time ?? 0)}ms</span>
	{/if}
{/snippet}
