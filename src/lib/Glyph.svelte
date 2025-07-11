<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';

	interface Props {
		glyph: string;
		size?: string | undefined;
		attrs?: SvelteHTMLElements['span'] | undefined;
	}

	const {glyph, size, attrs}: Props = $props();

	const DEFAULT_SIZE = 'var(--font_size, 1em)';
	const DEFAULT_FONT_SIZE = 'var(--font_size, inherit)';

	const final_size = $derived(size ?? DEFAULT_SIZE);
</script>

<span
	{...attrs}
	class="glyph display_inline_block text_align_center line_height_1 white_space_nowrap font_weight_400 {attrs?.class}"
	style:width={final_size}
	style:height={final_size}
	style:min-width={final_size}
	style:min-height={final_size}
	style:font-size={size ?? DEFAULT_FONT_SIZE}>{glyph}</span
>
