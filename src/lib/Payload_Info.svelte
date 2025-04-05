<script lang="ts">
	import type {Payload} from '$lib/payload_types.js';

	interface Props {
		payload: Payload;
	}

	const {payload}: Props = $props();
</script>

<!-- TODO -->
<pre>{JSON.stringify(payload, null, '\t')}</pre>
