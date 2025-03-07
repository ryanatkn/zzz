<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import Paste_From_Clipboard from '@ryanatkn/fuz/Paste_From_Clipboard.svelte';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import type {Bit} from '$lib/bit.svelte.js';
	import type {Prompts} from '$lib/prompts.svelte.js';
	import Xml_Tag_Controls from '$lib/Xml_Tag_Controls.svelte';
	import Bit_Stats from '$lib/Bit_Stats.svelte';
	import Clear_Restore_Button from '$lib/Clear_Restore_Button.svelte';
	import {GLYPH_PASTE} from '$lib/glyphs.js';

	interface Props {
		bit: Bit;
		prompts: Prompts;
	}

	const {bit, prompts}: Props = $props();

	const bit_textareas = $state<Record<string, HTMLTextAreaElement>>({});
</script>

<div class="column gap_sm" class:dormant={!bit.enabled}>
	<div class="flex mb_0 justify_content_space_between">
		<div class="size_lg m_0">{bit.name}</div>
	</div>
	<textarea
		style:height="200px"
		class="plain mb_0"
		bind:this={bit_textareas[bit.id]}
		value={bit.content}
		oninput={(e) => prompts.update_bit(bit.id, {content: e.currentTarget.value})}
		placeholder="content..."
	></textarea>
	<div class="flex justify_content_space_between">
		<div class="flex">
			<Copy_To_Clipboard text={bit.content} attrs={{class: 'plain'}} />
			<Paste_From_Clipboard
				onpaste={(text) => {
					bit.content += text;
					bit_textareas[bit.id].focus();
				}}
				attrs={{class: 'plain icon_button size_lg', title: 'paste'}}
				>{GLYPH_PASTE}</Paste_From_Clipboard
			>
			<Clear_Restore_Button
				value={bit.content}
				onchange={(value) => {
					bit.content = value;
				}}
			/>
			<!-- TODO restore -->
		</div>
		<Confirm_Button
			onclick={() => prompts.remove_bit(bit.id)}
			attrs={{title: `remove bit ${bit.id}`}}
		/>
	</div>
	<Bit_Stats length={bit.content.length} token_count={bit.token_count} />
	<Xml_Tag_Controls {bit} />
</div>
