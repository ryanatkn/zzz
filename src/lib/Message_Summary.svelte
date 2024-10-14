<script lang="ts">
	import type {Zzz_Message} from '$lib/zzz_message.js';

	interface Props {
		message: Zzz_Message;
	}

	const {message}: Props = $props();
</script>

<!-- TODO -->
<div class="row">
	{message.type}
	<div class="ellipsis font_mono">{JSON.stringify(message)}</div>
</div>
