<script lang="ts">
	import type {ComponentProps, Snippet} from 'svelte';
	import ContextmenuEntry from '@ryanatkn/fuz/ContextmenuEntry.svelte';
	import type {Thunk} from '@ryanatkn/belt/function.js';
	import type {OmitStrict} from '@ryanatkn/belt/types.js';

	import {GLYPH_COPY} from './glyphs.js';
	import {to_preview} from './helpers.js';
	import Glyph from './Glyph.svelte';

	const {
		content,
		label = 'copy',
		preview,
		preview_limit,
		show_preview = true,
		children,
		...rest
	}: OmitStrict<ComponentProps<typeof ContextmenuEntry>, 'run' | 'children'> & {
		content: string | Thunk<string> | undefined;
		label?: string | undefined;
		preview?: string | undefined;
		preview_limit?: number | undefined;
		show_preview?: boolean | undefined; // TODO maybe rename to `nopreview`?
		children?: Snippet | undefined;
	} = $props();

	const read_content = () => (typeof content === 'function' ? content() : content);

	const final_preview: string | undefined = $derived(
		show_preview ? to_preview(preview ?? read_content(), preview_limit) : undefined,
	);

	const copy_to_clipboard = async (): Promise<void> => {
		const c = read_content();
		if (!c) return;
		try {
			await navigator.clipboard.writeText(c);
		} catch (error) {
			console.error('failed to copy text: ', error);
		}
	};
</script>

<ContextmenuEntry run={copy_to_clipboard} {...rest}>
	{#snippet icon()}<Glyph glyph={GLYPH_COPY} />{/snippet}
	{#if children}
		{@render children()}
	{:else}
		<span>
			{label}
			{#if final_preview}
				<small class="ml_xs">{final_preview}</small>
			{/if}
		</span>
	{/if}
</ContextmenuEntry>
