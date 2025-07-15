<script lang="ts">
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';
	import type {ComponentProps} from 'svelte';

	import {Text_Bit} from '$lib/bit.svelte.js';
	import Content_Editor from '$lib/Content_Editor.svelte';

	const {
		text_bit,
		show_actions = true,
		...rest
	}: Omit_Strict<ComponentProps<typeof Content_Editor>, 'content'> & {
		text_bit: Text_Bit;
	} = $props();
</script>

<Content_Editor {...rest} bind:content={text_bit.content} {show_actions} />
