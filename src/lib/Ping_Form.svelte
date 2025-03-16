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

	const HISTORY_SIZE = 6;

	// Use the derived index directly
	const pongs = $derived(zzz.messages.items.get_derived('latest_pongs'));
	$inspect('pongs', pongs);

	// Create paired ping-pong entries with their timing data
	const display_items = $derived.by(() => {
		const result: Array<{pong_id: string; ping_id: string; response_time?: number}> = [];
		for (const pong of pongs) {
			if (!pong.ping_id) continue;
			const response_time = zzz.ping_elapsed.get(pong.ping_id);
			result.push({
				pong_id: pong.id,
				ping_id: pong.ping_id,
				response_time,
			});
		}
		return result;
	});
	$inspect('display_items', display_items);

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
		class="unstyled overflow_hidden scrollbar_width_thin column panel p_md pb_0 mb_0 shadow_inset_top_xs"
		style:height="150px"
	>
		{#each display_items as item (item.pong_id)}
			<li transition:slide>
				{#if item.response_time !== undefined}
					{@render ping_item(item.response_time)}
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
</div>

{#snippet ping_item(response_time: number)}
	{GLYPH_DIRECTION_CLIENT}{GLYPH_DIRECTION_SERVER}
	<span class="font_mono">{Math.round(response_time)}ms</span>
{/snippet}
