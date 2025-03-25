<script lang="ts">
	import type {ComponentProps, Snippet} from 'svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import {GLYPH_COPY} from '$lib/glyphs.js';

	interface Props
		extends Omit_Strict<ComponentProps<typeof Contextmenu_Entry>, 'run' | 'children'> {
		content: string | undefined;
		label?: string | undefined;
		preview?: string | undefined;
		preview_limit?: number | undefined;
		show_preview?: boolean | undefined;
		children?: Snippet | undefined;
	}

	const {
		content,
		label = 'copy',
		preview,
		preview_limit = 40,
		show_preview = true,
		children,
		...rest
	}: Props = $props();

	const final_preview: string | undefined = $derived.by(() => {
		if (!show_preview) return undefined;
		const p = preview ?? content;
		if (!p) return undefined;
		if (p.length <= preview_limit) return p;
		return p.substring(0, preview_limit) + '...';
	});

	const copy_to_clipboard = async (): Promise<void> => {
		if (!content) return;
		try {
			await navigator.clipboard.writeText(content);
		} catch (error) {
			console.error('Failed to copy text: ', error);
		}
	};
</script>

<Contextmenu_Entry run={copy_to_clipboard} {...rest}>
	{#snippet icon()}{GLYPH_COPY}{/snippet}
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
</Contextmenu_Entry>
