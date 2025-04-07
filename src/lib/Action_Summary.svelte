<script lang="ts">
	import type {Action} from '$lib/action_types.js';

	interface Props {
		action: Action;
	}

	const {action}: Props = $props();
</script>

<!-- TODO -->
<div class="row">
	{action.type}
	<div class="ellipsis font_mono">{JSON.stringify(action)}</div>
</div>
