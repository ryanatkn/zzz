<script lang="ts">
	import {scale} from 'svelte/transition';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import type {Snippet} from 'svelte';

	interface Props {
		onclick: () => void;
		attrs?: SvelteHTMLElements['button'];
		button_attrs?: SvelteHTMLElements['button'];
		button?: Snippet<[confirming: boolean, toggle: () => void]>;
		children?: Snippet<[confirming: boolean]>;
	}
	const {onclick, children, button, button_attrs, attrs}: Props = $props();

	if (children && button) {
		console.warn('Confirm_Button has both children and button defined - button takes precedence');
	}

	let confirming = $state(false);
	const toggle = () => (confirming = !confirming);

	// TODO BLOCK make the active state visible on the button when `confirming=true`, but `selected` is too visually heavy

	// TODO changing the font size works if there's no children, but that's a weird difference - the UX is broken for custom buttons because they change size when the font size changes

	// TODO add contextmenu behavior to dismiss the confirmation button

	// This hides the confirmation button when the button is disabled.
	// TODO do it more declaratively without the effect and instead use derived?
	// But then `confirming` would need to be split into `confirming`
	// with either `confirming_open` or `final_confirming`?
	$effect.pre(() => {
		if (button_attrs?.disabled) {
			confirming = false;
		}
	});
</script>

<!-- I did the ternary below because Svelte treats `undefined` `class:` directive values as `false`, so they override the attribute classes -->
<!-- eslint-disable svelte/prefer-class-directive -->

<div class="relative">
	{#if button}
		{@render button(confirming, toggle)}
	{:else}
		<button
			type="button"
			onclick={toggle}
			class:confirming
			{...button_attrs}
			class="{button_attrs?.class} {!children && !button_attrs?.class?.includes('icon_button')
				? 'icon_button'
				: ''} {!children && !confirming && !button_attrs?.class?.includes('plain')
				? 'plain'
				: ''} {!children && confirming && !button_attrs?.class?.includes('size_sm')
				? 'size_sm'
				: ''}"
		>
			{#if children}{@render children(confirming)}{:else}🗙{/if}
		</button>
	{/if}
	{#if confirming}
		<button
			type="button"
			class="color_c absolute icon_button bg_c_1"
			style:left="calc(-1 * var(--input_height))"
			style:top="0"
			style:transform-origin="right"
			onclick={() => {
				confirming = false;
				onclick();
			}}
			in:scale={{duration: 80}}
			out:scale={{duration: 200}}
			{...attrs}
		>
			🗙
		</button>
	{/if}
</div>
