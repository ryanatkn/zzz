<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';

	import type {Bit_Union} from '$lib/bit.svelte.js';
	import type {Prompt} from '$lib/prompt.svelte.js';
	import type {Prompts} from '$lib/prompts.svelte.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	const {
		bit,
		prompt,
		prompts,
		...rest
	}: SvelteHTMLElements['button'] & {
		bit: Bit_Union;
		prompt?: Prompt | undefined;
		prompts?: Prompts | undefined;
	} = $props();
</script>

<Confirm_Button
	{...rest}
	onconfirm={() => {
		if (prompt) {
			prompt.remove_bit(bit.id);
		} else if (prompts) {
			prompts.remove_bit(bit.id);
		}
	}}
	class="plain compact"
	title="remove bit {'"' + bit.name + '"'}"
>
	<Glyph glyph={GLYPH_REMOVE} />
</Confirm_Button>
