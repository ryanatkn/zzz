<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';

	interface Props {
		icon: string;
		size?: string;
		attrs?: SvelteHTMLElements['span'];
	}

	const {icon, size = 'var(--size, var(--icon_size_md))', attrs}: Props = $props();

	// TODO BLOCK refactor with `icon_xs`
</script>

<span
	class="inline_block text_align_center"
	style:width={size}
	style:height={size}
	style:font-size={size}
	{...attrs}>{icon}</span
>
