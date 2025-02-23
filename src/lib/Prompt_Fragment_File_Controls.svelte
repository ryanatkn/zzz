<script lang="ts">
	import {scale} from 'svelte/transition';

	import type {Prompt_Fragment} from '$lib/prompt.svelte.js';
	import type {Prompts} from '$lib/prompts.svelte.js';

	interface Props {
		fragment: Prompt_Fragment;
		prompts: Prompts;
	}

	const {fragment, prompts}: Props = $props();
</script>

<div class="flex gap_md align_items_center">
	<label class="row mb_0" style:height="var(--input_height)">
		<input
			type="checkbox"
			checked={fragment.is_file}
			onchange={(e) => prompts.update_fragment(fragment.id, {is_file: e.currentTarget.checked})}
		/>
		is file
	</label>
	{#if fragment.is_file}
		<div in:scale={{duration: 80}} out:scale={{duration: 200}} style:transform-origin="center left">
			<input
				type="text"
				class="flex_1"
				placeholder="/path/to/file"
				value={fragment.file_path}
				oninput={(e) => prompts.update_fragment(fragment.id, {file_path: e.currentTarget.value})}
			/>
		</div>
	{/if}
</div>
