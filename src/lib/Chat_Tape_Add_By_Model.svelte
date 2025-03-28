<script lang="ts">
	import Model_Selector from '$lib/Model_Selector.svelte';
	import type {Chat} from '$lib/chat.svelte.js';
	import type {Model} from '$lib/model.svelte.js';
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
	<header class="mb_md size_lg">add by model</header>
	<Model_Selector onselect={(model: Model) => chat.add_tape(model)} {children} />
</div>
