<script lang="ts">
	import {scale} from 'svelte/transition';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import type {Snippet} from 'svelte';

	import {GLYPH_REMOVE} from '$lib/glyphs.js';

	interface Props {
		onclick: () => void;
		attrs?: SvelteHTMLElements['button'];
		button?: Snippet<[confirming: boolean, toggle: () => void]>;
		confirm_button_attrs?: SvelteHTMLElements['button'];
		children?: Snippet<[confirming: boolean]>;
	}
	const {onclick, children, button, attrs, confirm_button_attrs}: Props = $props();

	if (children && button) {
		console.warn('Confirm_Button has both children and button defined - button takes precedence');
	}

	let confirming = $state(false);
	const toggle = () => (confirming = !confirming);

	// TODO BLOCK probably replace the remove button with an edit button that also changes the name to be an editable input,
	// and the remove button expands from the edit button, and there's also a save button

	// TODO BLOCK make the active state visible on the button when `confirming=true`, but `selected` is too visually heavy

	// TODO changing the font size works if there's no children, but that's a weird difference - the UX is broken for custom buttons because they change size when the font size changes

	// TODO add contextmenu behavior to dismiss the confirmation button

	// This hides the confirmation button when the button is disabled.
	// TODO do it more declaratively without the effect and instead use derived?
	// But then `confirming` would need to be split into `confirming`
	// with either `confirming_open` or `final_confirming`?
	$effect.pre(() => {
		if (attrs?.disabled) {
			confirming = false;
		}
	});

	const c = $derived(attrs?.class);
</script>

<!-- I did the ternary below because Svelte treats `undefined` `class:` directive values as `false`, so they override the attribute classes -->
<!-- eslint-disable svelte/prefer-class-directive -->

<!-- TODO the class detection is hacky, probably move to props -->

<div class="relative">
	{#if button}
		{@render button(confirming, toggle)}
	{:else}
		<button
			type="button"
			onclick={toggle}
			class:confirming
			{...attrs}
			class="{c} {!children && !c?.includes('icon_button') ? 'icon_button' : ''} {!children &&
			!confirming &&
			!c?.includes('plain')
				? 'plain'
				: ''} {!children &&
			confirming &&
			!c?.includes(c.includes('compact') ? 'size_xs' : 'size_sm')
				? c?.includes('compact')
					? 'size_xs'
					: 'size_sm'
				: ''}"
		>
			{#if children}{@render children(confirming)}{:else}{GLYPH_REMOVE}{/if}
		</button>
	{/if}
	{#if confirming}
		<button
			type="button"
			class="color_c absolute icon_button bg_c_1"
			style:left="calc(-1 * var(--input_height))"
			style:top="0"
			style:transform-origin="right"
			style:z-index="10"
			onclick={() => {
				confirming = false;
				onclick();
			}}
			in:scale={{duration: 80}}
			out:scale={{duration: 200}}
			{...confirm_button_attrs}
		>
			<div class="icon">{GLYPH_REMOVE}</div>
		</button>
	{/if}
</div>

<style>
	.icon {
		transform-origin: center;
		transition: transform var(--duration_1);
	}

	button:hover:not(:disabled) .icon {
		transform: scale(1.1);
	}

	button:active:not(:disabled) .icon {
		transform: scale(0.95);
	}
</style>
