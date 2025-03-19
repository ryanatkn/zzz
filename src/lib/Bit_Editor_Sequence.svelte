<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';
	import Bit_List from '$lib/Bit_List.svelte';
	import Content_Preview from '$lib/Content_Preview.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {Uuid} from '$lib/zod_helpers.js';
	import {Bit, type Sequence_Bit} from '$lib/bit.svelte.js';
	import {GLYPH_ADD} from '$lib/glyphs.js';

	interface Props {
		sequence_bit: Sequence_Bit;
		prompt?: Prompt;
	}

	const {sequence_bit, prompt}: Props = $props();

	const zzz = zzz_context.get();

	// Handle reordering of bits within the sequence
	const handle_reorder = (from_index: number, to_index: number) => {
		const bit_id = sequence_bit.items[from_index];
		sequence_bit.move(bit_id, to_index);
	};

	// Available bits that can be added to the sequence (excluding self and already included bits)
	const available_bits = $derived(
		zzz.bits.items.all.filter(
			(bit) => bit.id !== sequence_bit.id && !sequence_bit.items.includes(bit.id),
		),
	);

	// Add a bit to the sequence
	const add_bit_to_sequence = (bit_id: Uuid) => {
		sequence_bit.add(bit_id);
	};

	// Create a new text bit and add it to the sequence
	const create_bit = () => {
		const new_bit = Bit.create(zzz, {
			type: 'text',
			content: '',
			name: 'Sequence item',
		});

		// Add to global bits collection
		zzz.bits.add(new_bit);

		// Add to this sequence
		sequence_bit.add(new_bit.id);
	};
</script>

<div class="sequence_bit_content p_xs bg_1 radius_xs">
	<div class="flex justify_content_space_between mb_xs">
		<div class="size_sm">
			{sequence_bit.items.length} bit{sequence_bit.items.length !== 1 ? 's' : ''}
		</div>
		<div class="flex gap_xs">
			<button type="button" class="plain size_sm" onclick={create_bit}>
				{GLYPH_ADD} add bit
			</button>
		</div>
	</div>

	{#if sequence_bit.bits.length === 0}
		<div class="p_xs bg_2 radius_xs size_sm">
			<em>No bits in sequence</em>
		</div>
	{:else}
		<Bit_List
			bits={sequence_bit.bits}
			{prompt}
			onreorder={handle_reorder}
			attrs={{class: 'mb_xs'}}
			item_attrs={{class: 'bg_2'}}
		/>
	{/if}

	{#if available_bits.length > 0}
		<div class="mt_xs">
			<select
				class="w_100 mb_0"
				onchange={(e) => {
					const selected_bit_id = e.currentTarget.value;
					if (selected_bit_id) {
						add_bit_to_sequence(selected_bit_id as Uuid);
						e.currentTarget.value = '';
					}
				}}
			>
				<option value="">Add an existing bit to sequence...</option>
				{#each available_bits as available_bit}
					<option value={available_bit.id}>{available_bit.name}</option>
				{/each}
			</select>
		</div>
	{/if}

	<Content_Preview content={sequence_bit.content} />
</div>
