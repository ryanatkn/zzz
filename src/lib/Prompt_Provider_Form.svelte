<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';

	import type {Provider} from '$lib/provider.svelte.js';

	interface Props {
		provider: Provider;
		onsubmit: (value: string) => void;
		pending: boolean;
	}

	const {provider, onsubmit, pending}: Props = $props();

	let value = $state('');

	let textarea_el: HTMLTextAreaElement | undefined = $state();

	// TODO connect `Claude` to the server data in `src/routes/gui/gui.server.svelte`
</script>

<textarea bind:this={textarea_el} placeholder="prompt" bind:value></textarea>
<Pending_Button
	{pending}
	onclick={() => {
		if (!value) {
			textarea_el?.focus();
			return;
		}
		onsubmit(value);
	}}
>
	prompt {provider.title}
</Pending_Button>
