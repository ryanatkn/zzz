<script lang="ts">
	import type {OmitStrict} from '@ryanatkn/belt/types.js';

	import type {XmlAttributeWithDefaults} from '$lib/xml.js';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';
	import ConfirmButton from '$lib/ConfirmButton.svelte';
	import Glyph from '$lib/Glyph.svelte';

	const {
		attribute,
		dormant: dormant_prop,
		onupdate,
		onremove,
	}: {
		attribute: XmlAttributeWithDefaults;
		dormant?: boolean | undefined;
		onupdate: (updates: Partial<OmitStrict<XmlAttributeWithDefaults, 'id'>>) => void;
		onremove: () => void;
	} = $props();

	const dormant = $derived(dormant_prop || !attribute.key);
</script>

<div class="display_flex gap_xs2 align_items_center" class:dormant_wrapper={!attribute.key}>
	<input
		class="plain compact"
		class:dormant
		placeholder="key"
		value={attribute.key}
		oninput={(e) => onupdate({key: e.currentTarget.value})}
	/>
	<input
		class="plain compact"
		class:dormant
		placeholder="value"
		value={attribute.value}
		oninput={(e) => onupdate({value: e.currentTarget.value})}
	/>
	<ConfirmButton
		onconfirm={onremove}
		title="remove attribute {attribute.key || ''}"
		class="plain compact"
	>
		<Glyph glyph={GLYPH_REMOVE} />
	</ConfirmButton>
</div>
