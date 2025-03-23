<script lang="ts">
	import {encode as tokenize} from 'gpt-tokenizer';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import type {Snippet} from 'svelte';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import Paste_From_Clipboard from '@ryanatkn/fuz/Paste_From_Clipboard.svelte';

	import Content_Stats from '$lib/Content_Stats.svelte';
	import Clear_Restore_Button from '$lib/Clear_Restore_Button.svelte';
	import {GLYPH_PASTE, GLYPH_PLACEHOLDER} from '$lib/glyphs.js';

	interface Props {
		content: string;
		onchange?: (content: string) => void;
		placeholder?: string | null | undefined;
		readonly?: boolean;
		show_stats?: boolean;
		show_actions?: boolean;
		textarea_height?: string;
		attrs?: SvelteHTMLElements['textarea'];
		children?: Snippet;
	}

	const {
		content,
		onchange,
		placeholder = GLYPH_PLACEHOLDER,
		readonly = false,
		show_stats = false,
		show_actions = false,
		textarea_height,
		attrs,
		children,
	}: Props = $props();

	let textarea_el: HTMLTextAreaElement | undefined = $state();

	const content_length = $derived(content.length);
	const content_tokens = $derived(tokenize(content)); // TODO BLOCK duplicates work, pass a class instance instead?
	const token_count = $derived(content_tokens.length);

	/**
	 * Focus the textarea element - exposed for parent components
	 */
	export const focus = (): void => {
		textarea_el?.focus();
	};
</script>

<div class="column w_100 flex_1">
	<div class="flex flex_1 gap_xs2 w_100">
		<textarea
			{...attrs}
			class="plain mb_0 w_100 h_100 flex_1 {attrs?.class}"
			bind:this={textarea_el}
			value={content}
			{placeholder}
			{readonly}
			style="{textarea_height ? `height: ${textarea_height};` : ''} {attrs?.style || ''}"
			oninput={(e) => onchange?.(e.currentTarget.value)}
		></textarea>
		{@render children?.()}
	</div>

	{#if show_stats}
		<Content_Stats length={content_length} {token_count} />
	{/if}

	{#if show_actions && !readonly}
		<div class="flex mt_xs">
			<Copy_To_Clipboard text={content} attrs={{class: 'plain'}} />
			<Paste_From_Clipboard
				onpaste={(value) => {
					const new_content = content + value;
					onchange?.(new_content);
					textarea_el?.focus();
				}}
				attrs={{class: 'plain icon_button size_lg'}}
			>
				{GLYPH_PASTE}
			</Paste_From_Clipboard>
			<Clear_Restore_Button
				value={content}
				onchange={(value) => {
					onchange?.(value);
					textarea_el?.focus();
				}}
			/>
		</div>
	{/if}
</div>
