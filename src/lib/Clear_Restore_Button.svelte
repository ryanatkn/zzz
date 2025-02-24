<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';

	interface Props {
		value: string;
		onchange: (value: string) => void;
		attrs?: SvelteHTMLElements['button'];
	}

	const {value, onchange, attrs}: Props = $props();

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
		<span style:visibility="hidden">restore</span>
		<span class="absolute" style:inset="0"
			>{#if value || !cleared_value}clear{:else}restore{/if}</span
		>
	</span>
</button>
