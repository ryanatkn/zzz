<script lang="ts">
	import {slide} from 'svelte/transition';

	import type {Bit} from '$lib/bit.svelte.js';
	import Xml_Attribute_Editor from '$lib/Xml_Attribute_Editor.svelte';
	import {XML_TAG_NAME_DEFAULT} from '$lib/constants.js';

	interface Props {
		bit: Bit;
	}

	const {bit}: Props = $props();

	let input_el: HTMLInputElement | undefined;
</script>

<div class="flex gap_xs align_items_start column">
	<div class="flex align_items_center gap_xs2 w_100">
		<label
			class="row mb_0"
			style:height="var(--input_height)"
			title="when enabled, the prompt's content will be wrapped with the xml tag '{bit.xml_tag_name ||
				XML_TAG_NAME_DEFAULT}'"
		>
			xml tag
			<input
				class="plain compact ml_md size_md"
				type="checkbox"
				bind:checked={
					() => bit.has_xml_tag,
					(v) => {
						bit.has_xml_tag = v;
						if (v) input_el?.focus(); // I like this compared to an $effect placed in some arbitrary place
					}
				}
			/>
		</label>
		<input
			class="plain flex_1"
			class:dormant={!bit.has_xml_tag}
			placeholder={bit.has_xml_tag ? '⤻ xml tag name' : undefined}
			bind:value={bit.xml_tag_name}
			bind:this={input_el}
		/>
		<button
			type="button"
			class="icon_button plain"
			title="add xml attribute"
			onclick={() => bit.add_attribute()}
		>
			✛
		</button>
	</div>

	<div class="attributes column gap_xs2">
		{#each bit.attributes as attribute (attribute.id)}
			<div transition:slide>
				<Xml_Attribute_Editor
					{attribute}
					dormant={!bit.has_xml_tag}
					onupdate={(updates) => bit.update_attribute(attribute.id, updates)}
					onremove={() => bit.remove_attribute(attribute.id)}
				/>
			</div>
		{/each}
	</div>
</div>
