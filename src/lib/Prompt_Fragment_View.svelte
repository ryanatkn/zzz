<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import type {Prompt_Fragment} from '$lib/prompt.svelte.js';
	import type {Prompts} from '$lib/prompts.svelte.js';
	import Prompt_Fragment_File_Controls from '$lib/Prompt_Fragment_File_Controls.svelte';

	interface Props {
		fragment: Prompt_Fragment;
		prompts: Prompts;
		fragment_textareas: Record<string, HTMLTextAreaElement>;
	}

	const {fragment, prompts, fragment_textareas}: Props = $props();
</script>

<div class="column gap_sm">
	<div class="flex justify_content_space_between mb_sm">
		<h3 class="m_0">{fragment.name}</h3>
	</div>
	<textarea
		style:height="200px"
		class="mb_xs"
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
				onclick={() => {
					fragment.content = '';
				}}>clear</button
			>
			<!-- TODO undo -->
		</div>
		<Confirm_Button
			onclick={() => prompts.remove_fragment(fragment.id)}
			button_attrs={{title: `remove fragment ${fragment.id}`}}
		/>
	</div>
	<Prompt_Fragment_File_Controls {fragment} {prompts} />
</div>
