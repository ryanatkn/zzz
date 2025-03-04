<script lang="ts">
	import type {Message} from '$lib/message_types.js';

	interface Props {
		message: Message;
	}

	const {message}: Props = $props();
</script>

<!-- TODO -->
<div class="row">
	{message.type}
	<div class="ellipsis font_mono">{JSON.stringify(message)}</div>
</div>
