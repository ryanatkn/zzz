<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Alert from '@ryanatkn/fuz/Alert.svelte';

	const props: ComponentProps<typeof Alert> = $props();
</script>

<Alert status="error" {...props} />
