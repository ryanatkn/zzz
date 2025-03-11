<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';
	import type {ComponentProps, Snippet} from 'svelte';
	import {DEV} from 'esm-env';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import Popover_Button from '$lib/Popover_Button.svelte';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';
	import type {Popover} from '$lib/popover.svelte.js';

	interface Props
		extends Omit_Strict<ComponentProps<typeof Popover_Button>, 'popover_content' | 'children'> {
		onconfirm: (popover: Popover) => void;
		popover_button_attrs?: SvelteHTMLElements['button'];
		hide_on_confirm?: boolean;
		/** Unlike on `Popover_Button` this is optional and has a `confirm` arg */
		popover_content?: Snippet<[popover: Popover, confirm: () => void]>;
		/** Unlike on `Popover_Button` this has a `confirm` arg */
		children?: Snippet<[popover: Popover, confirm: () => void]>;
	}

	const {
		onconfirm,
		popover_button_attrs,
		hide_on_confirm = true,
		position = 'left',
		popover_content: popover_content_prop,
		button,
		children,
		...rest
	}: Props = $props();

	// TODO @many type union instead of this pattern?
	if (DEV) {
		if (popover_content_prop && popover_button_attrs) {
			console.error(
				'Confirm_Button has both popover_content and popover_attrs defined - popover_content takes precedence',
			);
		}
	}

	const confirm = (popover: Popover): void => {
		if (hide_on_confirm) popover.hide();
		onconfirm(popover);
	};
</script>

<Popover_Button {position} {button} {...rest} children={button ? undefined : children_default}>
	{#snippet popover_content(popover)}
		{#if popover_content_prop}
			{@render popover_content_prop(popover, () => confirm(popover))}
		{:else}
			<button
				type="button"
				class="icon_button color_c bg_c_1"
				onclick={() => confirm(popover)}
				{...popover_button_attrs}
			>
				<div>{GLYPH_REMOVE}</div>
			</button>
		{/if}
	{/snippet}
</Popover_Button>

{#snippet children_default(popover: Popover)}
	{#if children}
		{@render children(popover, () => confirm(popover))}
	{:else}
		{GLYPH_REMOVE}
	{/if}
{/snippet}
