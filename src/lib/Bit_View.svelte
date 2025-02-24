<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {count_tokens} from '$lib/prompt.svelte.js';
	import type {Bit} from '$lib/bit.svelte.js';
	import type {Prompts} from '$lib/prompts.svelte.js';
	import Xml_Tag_Controls from '$lib/Xml_Tag_Controls.svelte';
	import Bit_Stats from '$lib/Bit_Stats.svelte';
	import Clear_Restore_Button from '$lib/Clear_Restore_Button.svelte';

	interface Props {
		bit: Bit;
		prompts: Prompts;
	}

	const {bit, prompts}: Props = $props();

	const bit_textareas = $state<Record<string, HTMLTextAreaElement>>({});
</script>

<div class="column gap_sm">
	<div class="flex mb_0 justify_content_space_between">
		<div class="size_lg m_0">{bit.name}</div>
		<input
			type="checkbox"
			class="plain ml_md"
			title="this bit is {bit.enabled ? 'enabled' : 'disabled'} and {bit.enabled
				? ''
				: 'not '}included in the prompt"
			bind:checked={bit.enabled}
		/>
	</div>
	<textarea
		style:height="200px"
		class="mb_0"
		class:dormant_input={!bit.content}
		class:dormant={!bit.enabled}
		bind:this={bit_textareas[bit.id]}
		value={bit.content}
		oninput={(e) => prompts.update_bit(bit.id, {content: e.currentTarget.value})}
	></textarea>
	<div class="flex justify_content_space_between">
		<div class="flex">
			<Copy_To_Clipboard text={bit.content} classes="plain" />
			<button
				type="button"
				class="plain"
				onclick={async () => {
					bit.content += await navigator.clipboard.readText();
					bit_textareas[bit.id].focus();
				}}>paste</button
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
	<Xml_Tag_Controls {bit} />
	<Bit_Stats length={bit.content.length} token_count={count_tokens(bit.content)} />
</div>
