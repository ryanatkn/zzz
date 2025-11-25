<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';
	import type {OmitStrict} from '@ryanatkn/belt/types.js';

	import type {PartUnion} from '$lib/part.svelte.js';
	import type {Prompt} from '$lib/prompt.svelte.js';
	import type {Prompts} from '$lib/prompts.svelte.js';
	import ConfirmButton from '$lib/ConfirmButton.svelte';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	const {
		part,
		prompt,
		prompts,
		...rest
	}: OmitStrict<SvelteHTMLElements['button'], 'part'> & {
		part: PartUnion;
		prompt?: Prompt | undefined;
		prompts?: Prompts | undefined;
	} = $props();
</script>

<ConfirmButton
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
</ConfirmButton>
