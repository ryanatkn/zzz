<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';
	import Bit_List from '$lib/Bit_List.svelte';
	import Content_Preview from '$lib/Content_Preview.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import {Uuid} from '$lib/zod_helpers.js';
	import type {Sequence_Bit} from '$lib/bit.svelte.js';
	import {GLYPH_BIT} from '$lib/glyphs.js';
	import Bit_Picker_Dialog from '$lib/Bit_Picker_Dialog.svelte';
	import Glyph from '$lib/Glyph.svelte';

	interface Props {
		sequence_bit: Sequence_Bit;
		prompt?: Prompt | undefined;
	}

	const {sequence_bit, prompt}: Props = $props();

	const app = frontend_context.get();

	// Available bits that can be added to the sequence (excluding self and already included bits)
	const available_bits = $derived(
		// TODO @many should `items.by_id.values()` be a derived even if often inefficient? still better than constructing it multiple times? or should this be an index?
		Array.from(app.bits.items.by_id.values()).filter(
			(bit) => bit.id !== sequence_bit.id && !sequence_bit.items.includes(bit.id),
		),
	);

	// Add a bit to the sequence
	const add_bit_to_sequence = (bit_id: Uuid) => {
		sequence_bit.add(bit_id);
	};

	let show_bit_picker = $state(false);
</script>

<div class="row justify_content_space_between mb_xs">
	<div class="display_flex gap_xs">
		<button type="button" class="plain compact" onclick={() => (show_bit_picker = true)}>
			<Glyph glyph={GLYPH_BIT} /> add bit
		</button>
	</div>
	<small class="font_family_mono display_block">
		{sequence_bit.items.length} bit{sequence_bit.items.length !== 1 ? 's' : ''}
	</small>
</div>

{#if sequence_bit.bits.length > 0}
	<Bit_List
		bits={sequence_bit.bits}
		{prompt}
		onreorder={(from_index, to_index) => {
			const bit_id = sequence_bit.items[from_index];
			sequence_bit.move(bit_id, to_index);
		}}
		attrs={{class: 'mb_xs'}}
		item_attrs={{class: 'bg_2'}}
	/>
{/if}

{#if available_bits.length > 0}
	<div class="mb_xs">
		<select
			class="w_100 mb_0 compact"
			onchange={(e) => {
				const selected_bit_id = e.currentTarget.value;
				if (selected_bit_id) {
					add_bit_to_sequence(selected_bit_id as Uuid);
					e.currentTarget.value = '';
				}
			}}
		>
			<option value="">add existing bit to sequence...</option>
			{#each available_bits as available_bit (available_bit.id)}
				<option value={available_bit.id}>{available_bit.name}</option>
			{/each}
		</select>
	</div>
{/if}

<Content_Preview content={sequence_bit.content} />

<Bit_Picker_Dialog
	exclude_ids={[sequence_bit.id, ...sequence_bit.items]}
	bind:show={show_bit_picker}
	onpick={(bit) => {
		if (bit) {
			sequence_bit.add(bit.id);
		}
	}}
/>
