<script lang="ts">
	import type {Api_Message} from '$lib/api.js';

	interface Props {
		message: Api_Message;
	}

	const {message}: Props = $props();
</script>

<!-- TODO -->
<pre>{JSON.stringify(message, null, '\t')}</pre>
