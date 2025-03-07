<script lang="ts">
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {slide} from 'svelte/transition';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_DIRECTION_CLIENT, GLYPH_DIRECTION_SERVER} from '$lib/glyphs.js';

	const zzz = zzz_context.get();

	// Fixed history size
	const HISTORY_SIZE = 6;

	// TODO BLOCK failing here, is it being added?
	$inspect('pongs', zzz.messages.pongs);

	// Use the Messages collections directly with filter and limit
	const pongs = $derived(zzz.messages.by_type.get('pong')?.slice(-HISTORY_SIZE));
	$inspect(`pongs`, pongs);
	const pings = $derived(
		pongs?.map((p) => zzz.messages.by_id.get(p.ping_id!)).filter((p) => !!p) ?? [],
	);

	// Map of ping IDs to response times (use SvelteMap from zzz for reactivity)
	const ping_response_times = $derived(zzz.ping_elapsed);

	const displayed_pings = $derived(pings.slice().reverse());
	const remaining_placeholders = $derived(Math.max(0, HISTORY_SIZE - pings.length));
</script>

<div class="flex row gap_md">
	<div>
		<button type="button" onclick={() => zzz.send_ping()} class="flex_1">⚞ ping</button>
	</div>

	<ul class="ping_list p_md mt_md">
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
</div>

{#snippet ping_item(response_time: number)}
	{GLYPH_DIRECTION_CLIENT}{GLYPH_DIRECTION_SERVER}
	<span class="font_mono">{Math.round(response_time)}ms</span>
{/snippet}

<style>
	.ping_list {
		overflow-y: auto;
		scrollbar-width: thin;
		display: flex;
		flex-direction: column;
		background: var(--fg_1);
		border-radius: var(--radius_md);
		list-style: none;
	}
</style>
