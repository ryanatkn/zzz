<script lang="ts">
	import Prompt_Listitem from './Prompt_Listitem.svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import {Reorderable} from '$lib/reorderable.svelte.js';

	const zzz = zzz_context.get();
	const {prompts} = zzz;
	const selected_prompt_id = $derived(prompts.selected_id);

	const reorderable = new Reorderable();
</script>

<ul
	class="unstyled mt_sm"
	use:reorderable.list={{
		onreorder: (from_index, to_index) => prompts.reorder_prompts(from_index, to_index),
	}}
>
	{#each prompts.ordered_items as prompt, index (prompt.id)}
		<li use:reorderable.item={{index}}>
			<Prompt_Listitem {prompt} selected={prompt.id === selected_prompt_id} />
		</li>
	{/each}
</ul>
