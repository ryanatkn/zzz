<script lang="ts">
	import type {Api_Message} from '$lib/api.js';

	interface Props {
		message: Api_Message;
	}

	const {message}: Props = $props();
</script>

<!-- TODO -->
<div class="row">
	{message.type}
	<div class="ellipsis font_mono">{JSON.stringify(message)}</div>
</div>
