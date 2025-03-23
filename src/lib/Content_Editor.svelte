<script lang="ts">
	import {encode as tokenize} from 'gpt-tokenizer';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import type {Snippet} from 'svelte';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import Paste_From_Clipboard from '@ryanatkn/fuz/Paste_From_Clipboard.svelte';

	import Content_Stats from '$lib/Content_Stats.svelte';
	import Clear_Restore_Button from '$lib/Clear_Restore_Button.svelte';
	import {GLYPH_PASTE, GLYPH_PLACEHOLDER} from '$lib/glyphs.js';
	import {swallow} from '@ryanatkn/belt/dom.js';

	interface Props {
		content: string; // TODO maybe rename to value? rethink `Content_Editor` in general when we switch to CodeMirror
		/** `content` is tokenized to get this if not provided and `show_stats` is true. */
		token_count?: number;
		placeholder?: string | null | undefined;
		readonly?: boolean;
		show_stats?: boolean;
		show_actions?: boolean;
		textarea_height?: string;
		attrs?: SvelteHTMLElements['textarea'];
		after?: Snippet;
		children?: Snippet;
		onsave?: (value: string) => void;
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

	const content_tokens = $derived(tokenize(content));
	const token_count = $derived(token_count_prop ?? content_tokens.length);

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
	<div class="flex flex_1 gap_xs2 w_100">
		<textarea
			{...attrs}
			class="plain mb_0 w_100 h_100 flex_1 {attrs?.class}"
			bind:this={textarea_el}
			bind:value={content}
			{placeholder}
			{readonly}
			style="{textarea_height ? `height: ${textarea_height};` : ''} {attrs?.style || ''}"
		></textarea>
		{@render children?.()}
	</div>

	{#if show_stats}
		<Content_Stats length={content.length} {token_count} />
	{/if}

	{@render after?.()}

	{#if show_actions && !readonly}
		<div class="flex mt_xs">
			<Copy_To_Clipboard text={content} attrs={{class: 'plain'}} />
			<Paste_From_Clipboard
				onpaste={(value) => {
					const new_content = content + value;
					content = new_content;
					textarea_el?.focus();
				}}
				attrs={{class: 'plain icon_button size_lg'}}
			>
				{GLYPH_PASTE}
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
