<script lang="ts">
	import type {Snippet} from 'svelte';
	import type {SvelteHTMLElements} from 'svelte/elements';

	import {GLYPH_CLEAR, GLYPH_RESTORE} from '$lib/glyphs.js';
	import Toggle_Button from '$lib/Toggle_Button.svelte';

	interface Props {
		value: string;
		onchange: (value: string) => void;
		attrs?: SvelteHTMLElements['button'] | undefined;
		restore_icon?: Snippet | string | undefined;
		clear_icon?: Snippet | string | undefined;
	}

	const {
		value,
		onchange,
		attrs: attrs_prop,
		restore_icon = GLYPH_RESTORE,
		clear_icon = GLYPH_CLEAR,
	}: Props = $props();

	let cleared_value = $state('');

	const has_value = $derived(!!value);

	const disabled = $derived(!value && !cleared_value);
	const title = $derived(has_value ? 'clear' : 'restore');
	const attrs = $derived(attrs_prop ? {...attrs_prop, disabled, title} : {disabled, title});
</script>

<Toggle_Button
	active={has_value}
	active_content={clear_icon}
	inactive_content={restore_icon}
	ontoggle={(active) => {
		if (active) {
			// Restoring
			const restored = cleared_value;
			cleared_value = '';
			onchange(restored);
		} else {
			// Clearing
			cleared_value = value;
			onchange('');
		}
	}}
	{attrs}
/>
