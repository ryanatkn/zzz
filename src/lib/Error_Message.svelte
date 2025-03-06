<script lang="ts">
	import type {Snippet} from 'svelte';
	import Alert from '@ryanatkn/fuz/Alert.svelte';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();
</script>

<Alert status="error">
	{@render children()}
</Alert>
