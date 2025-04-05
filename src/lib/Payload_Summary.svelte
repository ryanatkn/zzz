<script lang="ts">
	import type {Payload} from '$lib/payload_types.js';

	interface Props {
		payload: Payload;
	}

	const {payload}: Props = $props();
</script>

<!-- TODO -->
<div class="row">
	{payload.type}
	<div class="ellipsis font_mono">{JSON.stringify(payload)}</div>
</div>
