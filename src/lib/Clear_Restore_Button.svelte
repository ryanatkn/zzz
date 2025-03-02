<script lang="ts">
	import type {Snippet} from 'svelte';
	import type {SvelteHTMLElements} from 'svelte/elements';

	interface Props {
		value: string;
		onchange: (value: string) => void;
		attrs?: SvelteHTMLElements['button'];
		restore?: Snippet;
		children?: Snippet;
	}

	const {value, onchange, attrs, restore, children}: Props = $props();

	let cleared_value = $state('');
</script>

<button
	type="button"
	class="plain"
	disabled={!value && !cleared_value}
	onclick={() => {
		if (value) {
			cleared_value = value;
			onchange('');
		} else {
			onchange(cleared_value);
			cleared_value = '';
		}
	}}
	{...attrs}
>
	<span class="relative">
		<span style:visibility="hidden" class="inline_flex flex_column"
			><span
				>{#if children}{@render children()}{:else}clear{/if}</span
			><span
				>{#if restore}{@render restore()}{:else}restore{/if}</span
			></span
		>
		<span class="absolute inline_flex align_items_center justify_content_center" style:inset="0"
			>{#if value || !cleared_value}{#if children}{@render children()}{:else}clear{/if}{:else if restore}{@render restore()}{:else}restore{/if}</span
		>
	</span>
</button>
