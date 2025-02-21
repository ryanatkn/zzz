<script lang="ts">
	import type {Source_File} from '@ryanatkn/gro/filer.js';
	import {to_root_path} from '$lib/path.js';

	interface Props {
		files: Map<string, Source_File>;
		selected_file_id?: string | null;
		onselect?: (file: Source_File) => void;
	}

	const {files, selected_file_id = null, onselect}: Props = $props();

	const sorted_files = $derived(
		Array.from(files.values()).sort((a, b) => to_root_path(a.id).localeCompare(to_root_path(b.id))),
	);

	const handle_select = (file: Source_File): void => {
		onselect?.(file);
	};
</script>

<div class="file_explorer">
	<menu class="files unstyled">
		{#each sorted_files as file (file.id)}
			<button
				type="button"
				class="file"
				class:selected={file.id === selected_file_id}
				onclick={() => handle_select(file)}
			>
				<div class="font_weight_400">
					<span class="mr_xs2">🗎</span>
					<small class="word_break_break_all">{to_root_path(file.id)}</small>
				</div>
			</button>
		{/each}
	</menu>
</div>

<style>
	.file_explorer {
		height: 100%;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.files {
		flex: 1;
		overflow-y: auto;
	}

	.file {
		justify-content: flex-start;
		width: 100%;
		text-align: left;
		padding: var(--space_xs2) var(--space_md);
		border-radius: 0;
		border: none;
		box-shadow: none;
	}
</style>
