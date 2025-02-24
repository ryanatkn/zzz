<script lang="ts">
	import type {Xml_Attribute} from '$lib/prompt.svelte.js';

	interface Props {
		attribute: Xml_Attribute;
		onupdate: (updates: Partial<Omit<Xml_Attribute, 'id'>>) => void;
		onremove: () => void;
	}

	const {attribute, onupdate, onremove}: Props = $props();
</script>

<div
	class="flex gap_xs2 align_items_center"
	class:dormant_wrapper={!attribute.key || !attribute.value}
>
	<input
		class="plain compact clean"
		class:dormant={!attribute.key}
		placeholder="key"
		value={attribute.key}
		oninput={(e) => onupdate({key: e.currentTarget.value})}
	/>
	<input
		class="plain compact clean"
		class:dormant={!attribute.value}
		placeholder="value"
		value={attribute.value}
		oninput={(e) => onupdate({value: e.currentTarget.value})}
	/>
	<button type="button" class="plain compact" onclick={onremove}>🗙</button>
</div>
