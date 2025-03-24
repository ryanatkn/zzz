<script lang="ts">
	import Picker from '$lib/Picker.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Bit_Type} from '$lib/bit.svelte.js';
	import type {Uuid} from '$lib/zod_helpers.js';

	const zzz = zzz_context.get();
	const {bits} = zzz;

	interface Props {
		onpick: (bit: Bit_Type | undefined) => boolean | void;
		show?: boolean | undefined;
		items?: Array<Bit_Type> | undefined;
		filter?: ((bit: Bit_Type) => boolean) | undefined;
		exclude_ids?: Array<Uuid> | undefined;
	}

	let {
		show = $bindable(false),
		onpick,
		items = bits.items.all,
		filter,
		exclude_ids = [],
	}: Props = $props();

	// TODO refactor
	const filtered_bits = $derived(
		items
			.filter((bit) => {
				// Check if the bit ID is in the exclude list
				if (exclude_ids.includes(bit.id)) {
					return false;
				}
				// Apply the custom filter if provided
				return filter ? filter(bit) : true;
			})
			.sort((a, b) => a.created_date.getTime() - b.created_date.getTime()),
	);
</script>

<Picker bind:show {onpick}>
	{#snippet children(pick)}
		<h2 class="mt_lg text_align_center">Pick a bit</h2>
		{#if filtered_bits.length === 0}
			<div class="p_md">No bits available</div>
		{:else}
			<ul class="unstyled">
				{#each filtered_bits as bit (bit.id)}
					<li>
						<button type="button" class="button_list_item compact w_100" onclick={() => pick(bit)}>
							<div class="p_xs size_sm">
								<span class="badge mr_xs">{bit.type}</span>
								<span class="text ellipsis">{bit.content_preview}</span>
							</div>
						</button>
					</li>
				{/each}
			</ul>
		{/if}
	{/snippet}
</Picker>
