<script lang="ts">
	import type {Message} from '$lib/message_types.js';

	interface Props {
		message: Message;
	}

	const {message}: Props = $props();
</script>

<!-- TODO -->
<pre>{JSON.stringify(message, null, '\t')}</pre>
