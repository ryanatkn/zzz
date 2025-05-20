<script lang="ts">
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import type {Xml_Attribute_With_Defaults} from '$lib/xml.js';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Glyph from '$lib/Glyph.svelte';

	interface Props {
		attribute: Xml_Attribute_With_Defaults;
		dormant?: boolean | undefined;
		onupdate: (updates: Partial<Omit_Strict<Xml_Attribute_With_Defaults, 'id'>>) => void;
		onremove: () => void;
	}

	const {attribute, dormant: dormant_prop, onupdate, onremove}: Props = $props();

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
	<Confirm_Button
		onconfirm={onremove}
		attrs={{title: `remove attribute ${attribute.key || ''}`, class: 'plain compact'}}
	>
		<Glyph glyph={GLYPH_REMOVE} />
	</Confirm_Button>
</div>
