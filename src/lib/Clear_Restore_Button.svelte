<script lang="ts">
	import type {Snippet} from 'svelte';
	import type {SvelteHTMLElements} from 'svelte/elements';

	import {GLYPH_CLEAR, GLYPH_RESTORE} from '$lib/glyphs.js';

	interface Props {
		value: string; // TODO change to a $bindable
		onchange: (value: string) => void;
		attrs?: SvelteHTMLElements['button'] | undefined;
		restore?: Snippet | undefined;
		children?: Snippet | undefined;
	}

	const {value, onchange, attrs, restore, children}: Props = $props();

	let cleared_value = $state('');
</script>

<button
	type="button"
	class="plain icon_button"
	disabled={!value && !cleared_value}
	title="{value ? 'clear' : 'restore'} content"
	onclick={() => {
		if (value) {
			cleared_value = value;
			onchange('');
		} else {
			onchange(cleared_value);
			cleared_value = '';
		}
	}}
	{...attrs}
>
	<span class="relative">
		<span style:visibility="hidden" class="inline_flex flex_column"
			><span
				>{#if children}{@render children()}{:else}{GLYPH_CLEAR}{/if}</span
			><span
				>{#if restore}{@render restore()}{:else}{GLYPH_RESTORE}{/if}</span
			></span
		>
		<span class="absolute inline_flex align_items_center justify_content_center" style:inset="0"
			>{#if value || !cleared_value}{#if children}{@render children()}{:else}{GLYPH_CLEAR}{/if}{:else if restore}{@render restore()}{:else}{GLYPH_RESTORE}{/if}</span
		>
	</span>
</button>
