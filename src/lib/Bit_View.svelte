<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {count_tokens} from '$lib/prompt.svelte.js';
	import type {Bit} from '$lib/bit.svelte.js';
	import type {Prompts} from '$lib/prompts.svelte.js';
	import Xml_Tag_Controls from '$lib/Xml_Tag_Controls.svelte';
	import Bit_Stats from '$lib/Bit_Stats.svelte';

	interface Props {
		bit: Bit;
		prompts: Prompts;
	}

	const {bit, prompts}: Props = $props();

	const bit_textareas = $state<Record<string, HTMLTextAreaElement>>({});

	let cleared_content = $state('');
</script>

<div class="column gap_sm">
	<label
		class="flex mb_0 justify_content_space_between"
		title="this prompt bit is {bit.enabled ? 'enabled' : 'disabled'}"
	>
		<div class="size_lg m_0">{bit.name}</div>
		<input type="checkbox" class="plain ml_md" bind:checked={bit.enabled} />
	</label>
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
			<button
				type="button"
				class="plain"
				disabled={!bit.content && !cleared_content}
				onclick={() => {
					if (bit.content) {
						cleared_content = bit.content;
						bit.content = '';
					} else {
						bit.content = cleared_content;
						cleared_content = '';
					}
				}}
			>
				<span class="relative">
					<span style:visibility="hidden">restore</span>
					<span class="absolute" style:inset="0"
						>{bit.content || !cleared_content ? 'clear' : 'restore'}</span
					>
				</span>
			</button>
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
