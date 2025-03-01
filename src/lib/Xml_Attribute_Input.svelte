<script lang="ts">
	import type {Xml_Attribute} from '$lib/xml.js';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';

	interface Props {
		attribute: Xml_Attribute;
		dormant?: boolean;
		onupdate: (updates: Partial<Omit<Xml_Attribute, 'id'>>) => void;
		onremove: () => void;
	}

	const {attribute, dormant, onupdate, onremove}: Props = $props();
</script>

<div
	class="flex gap_xs2 align_items_center"
	class:dormant_wrapper={!attribute.key || !attribute.value}
>
	<input
		class="plain compact"
		class:dormant={!!dormant || !attribute.key}
		placeholder="key"
		value={attribute.key}
		oninput={(e) => onupdate({key: e.currentTarget.value})}
	/>
	<input
		class="plain compact"
		class:dormant={!!dormant || !attribute.value}
		placeholder="value"
		value={attribute.value}
		oninput={(e) => onupdate({value: e.currentTarget.value})}
	/>
	<Confirm_Button
		onclick={onremove}
		attrs={{title: `remove attribute ${attribute.key || ''}`, class: 'plain compact'}}
	>
		{GLYPH_REMOVE}
	</Confirm_Button>
</div>
