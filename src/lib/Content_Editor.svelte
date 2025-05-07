<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';
	import type {Snippet} from 'svelte';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import Paste_From_Clipboard from '@ryanatkn/fuz/Paste_From_Clipboard.svelte';
	import {swallow} from '@ryanatkn/belt/dom.js';

	import {estimate_token_count} from '$lib/helpers.js';
	import Content_Stats from '$lib/Content_Stats.svelte';
	import Clear_Restore_Button from '$lib/Clear_Restore_Button.svelte';
	import {GLYPH_PASTE, GLYPH_PLACEHOLDER} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	interface Props {
		content: string; // TODO maybe rename to value? rethink `Content_Editor` in general when we switch to CodeMirror
		/** Estimated if not provided and `show_stats` is true. */
		token_count?: number | undefined;
		placeholder?: string | null | undefined;
		readonly?: boolean | undefined;
		show_stats?: boolean | undefined;
		show_actions?: boolean | undefined;
		textarea_height?: string | undefined;
		attrs?: SvelteHTMLElements['textarea'] | undefined;
		after?: Snippet | undefined;
		children?: Snippet | undefined;
		onsave?: ((value: string) => void) | undefined;
	}

	let {
		content = $bindable(),
		token_count: token_count_prop,
		placeholder = GLYPH_PLACEHOLDER,
		readonly = false,
		show_stats = false,
		show_actions = false,
		textarea_height,
		attrs,
		after,
		children,
		onsave,
	}: Props = $props();

	let textarea_el: HTMLTextAreaElement | undefined = $state();

	const token_count = $derived(token_count_prop ?? estimate_token_count(content));

	/**
	 * Focus the textarea element - exposed for parent components
	 */
	export const focus = (): void => {
		textarea_el?.focus();
	};
</script>

<svelte:document
	onkeydown={onsave
		? (event) => {
				// Check for Ctrl+S or Command+S (Mac)
				if ((event.ctrlKey || event.metaKey) && event.key === 's') {
					swallow(event);
					onsave(content);
				}
			}
		: undefined}
/>

<div class="column w_100 flex_1">
	<div class="display_flex flex_1 gap_xs2 w_100">
		<textarea
			{...attrs}
			class="plain mb_0 w_100 flex_1 {attrs?.class}"
			bind:this={textarea_el}
			bind:value={content}
			{placeholder}
			{readonly}
			style="{textarea_height ? `height: ${textarea_height};` : ''} {attrs?.style || ''}"
		></textarea>
		{@render children?.()}
	</div>

	{#if show_stats}
		<Content_Stats {token_count} />
	{/if}

	{@render after?.()}

	{#if show_actions && !readonly}
		<div class="display_flex mt_xs">
			<Copy_To_Clipboard text={content} attrs={{class: 'plain'}} />
			<Paste_From_Clipboard
				onpaste={(value) => {
					const new_content = content + value;
					content = new_content;
					textarea_el?.focus();
				}}
				attrs={{class: 'plain icon_button font_size_lg'}}
			>
				<!-- TODO should be default -->
				<Glyph glyph={GLYPH_PASTE} />
			</Paste_From_Clipboard>
			<Clear_Restore_Button
				value={content}
				onchange={(value) => {
					content = value;
					textarea_el?.focus();
				}}
			/>
		</div>
	{/if}
</div>
