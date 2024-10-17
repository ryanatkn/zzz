<script lang="ts">
	import {zzz_context} from '$lib/zzz.svelte.js';
	import File_List from '$lib/File_List.svelte';
	import Multiprompt from './Multiprompt.svelte';

	// interface Props {}

	// const {}: Props = $props();

	const zzz = zzz_context.get();

	// TODO
</script>

<!-- TODO drive with data -->
<section class="dashboard_prompts">
	<div class="w_100 flex_1">
		<Multiprompt />
	</div>
</section>
<section>
	<File_List files={zzz.files_by_id} />
</section>

<style>
	.dashboard_prompts {
		display: flex;
		width: 100%;
		padding: var(--space_md);
		gap: var(--space_md);
	}
</style>
