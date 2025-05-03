<script lang="ts">
	import Model_Picker from '$lib/Model_Picker.svelte';
	import type {Chat} from '$lib/chat.svelte.js';
	import type {Snippet} from 'svelte';
	import type {SvelteHTMLElements} from 'svelte/elements';

	// TODO better name? prioritizing clarity/colocation

	interface Props {
		chat: Chat;
		attrs?: SvelteHTMLElements['div'] | undefined;
		children?: Snippet | undefined;
	}

	const {chat, attrs, children}: Props = $props();
</script>

<div {...attrs} class="p_sm ${attrs?.class}">
	<header class="mb_md font_size_lg">add by model</header>
	<Model_Picker
		onpick={(model) => {
			if (model) {
				chat.add_tape(model);
			}
		}}
	/>
	{@render children?.()}
</div>
