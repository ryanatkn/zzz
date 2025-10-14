<script lang="ts">
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';
	import type {ComponentProps} from 'svelte';

	import {Text_Part} from '$lib/part.svelte.js';
	import Content_Editor from '$lib/Content_Editor.svelte';

	const {
		text_part,
		show_actions = true,
		...rest
	}: Omit_Strict<ComponentProps<typeof Content_Editor>, 'content'> & {
		text_part: Text_Part;
	} = $props();
</script>

<Content_Editor {...rest} bind:content={text_part.content} {show_actions} />
