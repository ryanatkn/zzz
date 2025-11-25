<script lang="ts">
	import type {OmitStrict} from '@ryanatkn/belt/types.js';
	import type {ComponentProps} from 'svelte';

	import {TextPart} from '$lib/part.svelte.js';
	import ContentEditor from '$lib/ContentEditor.svelte';

	const {
		text_part,
		show_actions = true,
		...rest
	}: OmitStrict<ComponentProps<typeof ContentEditor>, 'content'> & {
		text_part: TextPart;
	} = $props();
</script>

<ContentEditor {...rest} bind:content={text_part.content} {show_actions} />
