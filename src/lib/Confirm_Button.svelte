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
</script>

<div class="relative">
	{#if button}
		{@render button(confirming, toggle)}
	{:else}
		<button
			type="button"
			class:icon_button={!children}
			class:plain={!children && !confirming}
			class:size_sm={!children && confirming}
			onclick={toggle}
			{...button_attrs}
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
