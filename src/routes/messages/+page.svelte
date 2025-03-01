<script lang="ts">
	import Messages_List from '$lib/Messages_List.svelte';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();
</script>

<div class="p_lg">
	<h1><Text_Icon icon="📨" /> messages</h1>
	<p>View the communication between the client and server.</p>

	<div class="mt_md">
		<Messages_List limit={100} />
	</div>
</div>
