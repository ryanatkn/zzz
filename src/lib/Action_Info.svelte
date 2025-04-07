<script lang="ts">
	import type {Action} from '$lib/action_types.js';

	interface Props {
		action: Action;
	}

	const {action}: Props = $props();
</script>

<!-- TODO -->
<pre>{JSON.stringify(action, null, '\t')}</pre>
