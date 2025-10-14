<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import type {Part_Union} from '$lib/part.svelte.js';
	import type {Prompt} from '$lib/prompt.svelte.js';
	import type {Prompts} from '$lib/prompts.svelte.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	const {
		part,
		prompt,
		prompts,
		...rest
	}: Omit_Strict<SvelteHTMLElements['button'], 'part'> & {
		part: Part_Union;
		prompt?: Prompt | undefined;
		prompts?: Prompts | undefined;
	} = $props();
</script>

<Confirm_Button
	{...rest}
	onconfirm={() => {
		if (prompt) {
			prompt.remove_part(part.id);
		} else if (prompts) {
			prompts.remove_part(part.id);
		}
	}}
	class="plain compact"
	title="remove part {'"' + part.name + '"'}"
>
	<Glyph glyph={GLYPH_REMOVE} />
</Confirm_Button>
