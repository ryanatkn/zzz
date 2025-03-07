<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';

	interface Props {
		icon: string;
		size?: string;
		attrs?: SvelteHTMLElements['span'];
	}

	const {icon, size, attrs}: Props = $props();

	const DEFAULT_SIZE = 'var(--size, 1em)';
	const DEFAULT_FONT_SIZE = 'var(--size, inherit)';
</script>

<!-- TODO maybe set line height? -->
<span
	{...attrs}
	class="glyph inline_block text_align_center {attrs?.class}"
	style:width={size ?? DEFAULT_SIZE}
	style:height={size ?? DEFAULT_SIZE}
	style:font-size={size ?? DEFAULT_FONT_SIZE}>{icon}</span
>
