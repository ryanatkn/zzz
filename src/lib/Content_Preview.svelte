<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';

	interface Props {
		content: string;
		height?: string | undefined;
		min_height?: string | undefined;
		max_height?: string | undefined;
		attrs?: SvelteHTMLElements['pre'] | undefined;
	}

	const {
		content,
		height = '200px',
		min_height = height,
		max_height = height,
		attrs,
	}: Props = $props();
</script>

<pre
	{...attrs}
	style:height
	style:min-height={min_height}
	style:max-height={max_height}
	class="flex_1 w_100 overflow_auto scrollbar_width_thin radius_xs font_sans size_sm fg_1 px_md py_xs {attrs?.class}">{content}</pre>
