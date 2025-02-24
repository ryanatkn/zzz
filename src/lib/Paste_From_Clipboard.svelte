<script lang="ts">
	import type {Snippet} from 'svelte';
	import type {SvelteHTMLElements} from 'svelte/elements';

	interface Props {
		onpaste: (text: string) => void;
		attrs?: SvelteHTMLElements['button'];
		children?: Snippet;
	}
	const {onpaste, attrs, children}: Props = $props();
</script>

<button
	type="button"
	{...attrs}
	onclick={async () => {
		const text = await navigator.clipboard.readText();
		onpaste(text);
	}}
>
	{#if children}{@render children()}{:else}paste{/if}
</button>
