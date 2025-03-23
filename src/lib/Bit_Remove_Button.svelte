<script lang="ts">
	import type {Bit_Type} from '$lib/bit.svelte.js';
	import type {Prompt} from '$lib/prompt.svelte.js';
	import type {Prompts} from '$lib/prompts.svelte.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';

	interface Props {
		bit: Bit_Type;
		prompt?: Prompt | undefined;
		prompts?: Prompts | undefined;
		attrs?: Record<string, string> | undefined;
	}

	const {bit, prompt, prompts, attrs = {}}: Props = $props();

	const handle_remove = () => {
		if (prompt) {
			prompt.remove_bit(bit.id);
		} else if (prompts) {
			prompts.remove_bit(bit.id);
		}
	};
</script>

<Confirm_Button
	onconfirm={handle_remove}
	attrs={{
		class: `plain compact ${attrs.class || ''}`,
		title: `remove bit "${bit.name}"`,
		...attrs,
	}}
>
	{GLYPH_REMOVE}
</Confirm_Button>
