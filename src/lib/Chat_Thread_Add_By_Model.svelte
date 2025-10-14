<script lang="ts">
	import Model_Picker from '$lib/Model_Picker.svelte';
	import type {Chat} from '$lib/chat.svelte.js';
	import type {Snippet} from 'svelte';
	import type {SvelteHTMLElements} from 'svelte/elements';

	// TODO better name? prioritizing clarity/colocation

	const {
		chat,
		attrs,
		children,
	}: {
		chat: Chat;
		attrs?: SvelteHTMLElements['div'] | undefined;
		children?: Snippet | undefined;
	} = $props();
</script>

<div {...attrs} class="p_sm ${attrs?.class}">
	<header class="mb_md font_size_lg">add by model</header>
	<Model_Picker
		onpick={(model) => {
			if (model) {
				chat.add_thread(model);
			}
		}}
		heading={null}
	/>
	{@render children?.()}
</div>
