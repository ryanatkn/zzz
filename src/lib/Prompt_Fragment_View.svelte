<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {count_tokens, type Prompt_Fragment} from '$lib/prompt.svelte.js';
	import type {Prompts} from '$lib/prompts.svelte.js';
	import Xml_Tag_Controls from '$lib/Xml_Tag_Controls.svelte';
	import Prompt_Fragment_Stats from '$lib/Prompt_Fragment_Stats.svelte';

	interface Props {
		fragment: Prompt_Fragment;
		prompts: Prompts;
	}

	const {fragment, prompts}: Props = $props();

	const fragment_textareas = $state<Record<string, HTMLTextAreaElement>>({});

	let cleared_content = $state('');
</script>

<div class="column gap_sm">
	<label
		class="flex mb_0 justify_content_space_between"
		title="this prompt fragment is {fragment.enabled ? 'enabled' : 'disabled'}"
	>
		<h3 class="m_0">{fragment.name}</h3>
		<input type="checkbox" class="plain clean ml_md" bind:checked={fragment.enabled} />
	</label>
	<textarea
		style:height="200px"
		class="mb_0"
		class:dormant_input={!fragment.content}
		class:dormant={!fragment.enabled}
		bind:this={fragment_textareas[fragment.id]}
		value={fragment.content}
		oninput={(e) => prompts.update_fragment(fragment.id, {content: e.currentTarget.value})}
	></textarea>
	<div class="flex justify_content_space_between">
		<div class="flex">
			<Copy_To_Clipboard text={fragment.content} classes="plain" />
			<button
				type="button"
				class="plain"
				onclick={async () => {
					fragment.content += await navigator.clipboard.readText();
					fragment_textareas[fragment.id].focus();
				}}>paste</button
			>
			<button
				type="button"
				class="plain"
				disabled={!fragment.content && !cleared_content}
				onclick={() => {
					if (fragment.content) {
						cleared_content = fragment.content;
						fragment.content = '';
					} else {
						fragment.content = cleared_content;
						cleared_content = '';
					}
				}}
			>
				<span class="relative">
					<span style:visibility="hidden">restore</span>
					<span class="absolute" style:inset="0"
						>{fragment.content || !cleared_content ? 'clear' : 'restore'}</span
					>
				</span>
			</button>
			<!-- TODO restore -->
		</div>
		<Confirm_Button
			onclick={() => prompts.remove_fragment(fragment.id)}
			button_attrs={{title: `remove fragment ${fragment.id}`}}
		/>
	</div>
	<Xml_Tag_Controls {fragment} />
	<Prompt_Fragment_Stats
		length={fragment.content.length}
		token_count={count_tokens(fragment.content)}
	/>
</div>
