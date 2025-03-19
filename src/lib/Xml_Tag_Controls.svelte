<script lang="ts">
	import {slide} from 'svelte/transition';

	import type {Bit_Type} from '$lib/bit.svelte.js';
	import Xml_Attribute_Editor from '$lib/Xml_Attribute_Editor.svelte';
	import {XML_TAG_NAME_DEFAULT} from '$lib/constants.js';
	import {GLYPH_ADD, GLYPH_PLACEHOLDER} from '$lib/glyphs.js';

	interface Props {
		bit: Bit_Type;
	}

	const {bit}: Props = $props();

	let input_el: HTMLInputElement | undefined;
</script>

<div class="flex align_items_start column">
	<div class="flex align_items_center gap_xs2 w_100">
		<label
			class="row mb_0 pr_md"
			style:height="var(--input_height)"
			title="when enabled, the prompt's content will be wrapped with the xml tag '{bit.xml_tag_name ||
				XML_TAG_NAME_DEFAULT}'"
		>
			<input
				class="plain compact size_md"
				type="checkbox"
				bind:checked={
					() => bit.has_xml_tag,
					(v) => {
						bit.has_xml_tag = v;
						if (v) input_el?.focus(); // I like this compared to an $effect placed in some arbitrary place
					}
				}
			/>
			xml tag
		</label>
		<input
			class="plain flex_1 compact"
			class:dormant={!bit.has_xml_tag}
			placeholder={bit.has_xml_tag ? GLYPH_PLACEHOLDER + ' xml tag name' : undefined}
			bind:value={bit.xml_tag_name}
			bind:this={input_el}
		/>
		<button
			type="button"
			class="plain compact"
			title="add xml attribute"
			onclick={() => bit.add_attribute()}
		>
			{GLYPH_ADD}
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
