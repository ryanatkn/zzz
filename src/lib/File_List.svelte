<script lang="ts">
	import type {Source_File} from '@ryanatkn/gro/filer.js';

	import File_View from '$lib/File_View.svelte';

	interface Props {
		files: Array<Source_File>;
	}

	const {files}: Props = $props();
</script>

<ul class="unstyled flex column">
	{#each files as file (file.id)}
		<li>
			<File_View {file} />
		</li>
	{/each}
</ul>
