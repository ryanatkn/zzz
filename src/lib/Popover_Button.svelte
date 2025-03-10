<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';
	import type {Snippet} from 'svelte';
	import {scale} from 'svelte/transition';

	import {Popover} from '$lib/popover.svelte.js';
	import type {Position, Alignment} from '$lib/position_helpers.js';
	import {DEV} from 'esm-env';

	interface Props {
		position?: Position;
		align?: Alignment;
		disable_outside_click?: boolean;
		popover_class?: string;
		popover_attrs?: SvelteHTMLElements['div'];
		popover_content: Snippet<[popover: Popover]>;
		attrs?: SvelteHTMLElements['button'];
		button?: Snippet<[popover: Popover]>;
		children?: Snippet<[popover: Popover]>;
	}

	const {
		position = 'bottom',
		align = 'center',
		disable_outside_click = false,
		popover_class,
		popover_attrs,
		popover_content,
		attrs,
		button,
		children,
	}: Props = $props();

	if (DEV) {
		if (children && button) {
			console.error(
				'Popover_Button has both children and button defined - button takes precedence',
			);
		}
		if (!children && !button) {
			console.error('Popover_Button requires either children or a button snippet prop');
		}
	}

	// Create a popover instance
	const popover = new Popover();

	// This hides the popover when the button is disabled
	$effect.pre(() => {
		if (attrs?.disabled) {
			popover.hide();
		}
	});
</script>

<div class="flex">
	<div class="flex relative" use:popover.container>
		{#if button}
			{@render button(popover)}
		{:else}
			<button
				type="button"
				use:popover.trigger={{
					position,
					align,
					disable_outside_click,
				}}
				{...attrs}
			>
				{@render children?.(popover)}
			</button>
		{/if}

		{#if popover.visible}
			<div
				use:popover.content={{
					position,
					align,
					disable_outside_click,
					popover_class,
				}}
				in:scale={{duration: 80}}
				out:scale={{duration: 200}}
				{...popover_attrs}
			>
				{@render popover_content(popover)}
			</div>
		{/if}
	</div>
</div>
