<script lang="ts">
	import {slide} from 'svelte/transition';

	import type {Bit} from '$lib/bit.svelte.js';
	import Xml_Attribute from '$lib/Xml_Attribute.svelte';
	import {XML_TAG_NAME_DEFAULT} from '$lib/constants.js';

	interface Props {
		bit: Bit;
	}

	const {bit}: Props = $props();

	// TODO BLOCK visually show when the attributes are not being used, but don't actually disable them (maybe red outline? - similarly need something for bits that are empty)

	// TODO BLOCK experiment with the checkbox being a button with `.deselectable`
</script>

<div class="flex gap_xs align_items_start column">
	<div class="flex align_items_center gap_xs2">
		<label
			class="row mb_0"
			style:height="var(--input_height)"
			title="when enabled, the prompt's content will be wrapped with {bit.xml_tag_name ||
				XML_TAG_NAME_DEFAULT}"
		>
			xml tag
			<input class="plain ml_md" type="checkbox" bind:checked={bit.has_xml_tag} />
		</label>
		<input class="plain flex_1" placeholder="bit" bind:value={bit.xml_tag_name} />
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
				<Xml_Attribute
					{attribute}
					onupdate={(updates) => bit.update_attribute(attribute.id, updates)}
					onremove={() => bit.remove_attribute(attribute.id)}
				/>
			</div>
		{/each}
	</div>
</div>
