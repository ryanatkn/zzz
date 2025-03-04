<script lang="ts">
	import type {Diskfile} from '$lib/diskfile.svelte.js';

	import Diskfile_View from '$lib/Diskfile_View.svelte';

	interface Props {
		files: Array<Diskfile>;
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
