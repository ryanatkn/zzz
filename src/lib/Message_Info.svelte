<script lang="ts">
	import type {Zzz_Message} from '$lib/zzz_message.js';

	interface Props {
		message: Zzz_Message;
	}

	const {message}: Props = $props();
</script>

<!-- TODO -->
<pre>{JSON.stringify(message, null, '\t')}</pre>
