<script lang="ts">
	import type {Source_File} from '@ryanatkn/gro/filer.js';

	import Diskfile_View from '$lib/Diskfile_View.svelte';

	interface Props {
		files: Array<Source_File>;
	}

	const {files}: Props = $props();

	// TODO BLOCK delete this and children if not used
</script>

<ul class="unstyled flex column">
	{#each files as file (file.id)}
		<li>
			<Diskfile_View {file} />
		</li>
	{/each}
</ul>
