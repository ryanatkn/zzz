<script lang="ts">
	import {slide} from 'svelte/transition';

	import type {Prompt_Fragment} from '$lib/prompt.svelte.js';
	import Xml_Attribute from '$lib/Xml_Attribute.svelte';

	interface Props {
		fragment: Prompt_Fragment;
	}

	const {fragment}: Props = $props();

	// TODO BLOCK visually show when the attributes are not being used, but don't actually disable them (maybe red outline? - similarly need something for fragments that are empty)

	// TODO BLOCK experiment with the checkbox being a button with `.deselectable`
</script>

<div class="flex gap_xs align_items_start column">
	<div class="flex align_items_center gap_xs2">
		<label class="row mb_0" style:height="var(--input_height)">
			xml tag
			<input class="plain clean ml_md" type="checkbox" bind:checked={fragment.has_xml_tag} />
		</label>
		<input class="plain clean flex_1" placeholder="fragment" bind:value={fragment.xml_tag_name} />
		<button
			type="button"
			class="icon_button plain"
			title="add xml attribute"
			onclick={() => fragment.add_attribute()}
		>
			✛
		</button>
	</div>
	<div class="attributes column gap_xs2">
		{#each fragment.attributes as attribute (attribute.id)}
			<div transition:slide>
				<Xml_Attribute
					{attribute}
					onupdate={(updates) => fragment.update_attribute(attribute.id, updates)}
					onremove={() => fragment.remove_attribute(attribute.id)}
				/>
			</div>
		{/each}
	</div>
</div>
