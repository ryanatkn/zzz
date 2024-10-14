<script lang="ts">
	import type {SvelteMap} from 'svelte/reactivity';
	import type {Path_Id} from '@ryanatkn/gro/path.js';
	import type {Source_File} from '@ryanatkn/gro/filer.js';

	import File_View from '$lib/File_View.svelte';

	interface Props {
		// TODO more efficient data structures, reactive source files
		files: SvelteMap<Path_Id, Source_File>;
	}

	const {files}: Props = $props();
</script>

<ul class="unstyled flex column gap_md">
	{#each files.values() as file (file.id)}
		<li class="panel p_xs">
			<File_View {file} />
		</li>
	{/each}
</ul>
