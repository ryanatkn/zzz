<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Alert from '@ryanatkn/fuz/Alert.svelte';

	type Props = ComponentProps<typeof Alert>;

	const props: Props = $props();
</script>

<Alert status="error" {...props} />
