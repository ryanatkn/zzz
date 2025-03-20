<script lang="ts">
	import {slide} from 'svelte/transition';
	import type {Snippet} from 'svelte';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Diskfile_List_Item from '$lib/Diskfile_List_Item.svelte';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {GLYPH_DIRECTORY, GLYPH_CREATE_FILE, GLYPH_CREATE_FOLDER} from '$lib/glyphs.js';

	interface Props {
		empty?: Snippet;
	}

	const {empty}: Props = $props();

	const zzz = zzz_context.get();
	const {diskfiles} = zzz;

	// TODO need awaitable websocket calls?
	const TODO_create_file_pending = false;
	const TODO_create_folder_pending = false;

	// TODO add a select with name, name_reverse, created, created_reverse, updated, updated_reverse
	const sorted_files: Array<Diskfile> = $derived(
		[...diskfiles.non_external_files].sort((a, b) => {
			// Handle null/undefined path values
			if (!a.path && !b.path) return 0;
			if (!a.path) return 1; // null paths go last
			if (!b.path) return -1; // null paths go last

			return a.path.localeCompare(b.path);
		}),
	);

	// TODO improve UX to not use alert/prompt
	const create_file = () => {
		if (!zzz.zzz_dir) {
			alert('Cannot create file: no directory is selected'); // eslint-disable-line no-alert
			return;
		}

		const filename = prompt('New file name:'); // eslint-disable-line no-alert
		if (!filename) return;

		try {
			diskfiles.create_file(filename);
		} catch (error) {
			console.error('Failed to create file:', error);
			alert(`Failed to create file: ${error}`); // eslint-disable-line no-alert
		}
	};

	const create_folder = () => {
		if (!zzz.zzz_dir) {
			alert('Cannot create folder: no directory is selected'); // eslint-disable-line no-alert
			return;
		}

		const dirname = prompt('New folder name:'); // eslint-disable-line no-alert
		if (!dirname) return;

		try {
			diskfiles.create_directory(dirname);
		} catch (error) {
			console.error('Failed to create folder:', error);
			alert(`Failed to create folder: ${error}`); // eslint-disable-line no-alert
		}
	};
</script>

<div class="h_100 overflow_auto scrollbar_width_thin">
	{#if zzz.zzz_dir === undefined}
		<div>&nbsp;</div>
	{:else if zzz.zzz_dir === null}
		<div class="row h_input_height"><Pending_Animation /></div>
	{:else}
		<div class="row h_input_height justify_content_space_between py_xs px_xs">
			<small class="ellipsis"><Glyph_Icon icon={GLYPH_DIRECTORY} /> {zzz.zzz_dir_pathname}</small>
			<div class="flex gap_xs">
				<Pending_Button
					pending={TODO_create_file_pending}
					attrs={{class: 'plain compact'}}
					title="create file in {zzz.zzz_dir_pathname}"
					onclick={create_file}
				>
					<Glyph_Icon icon={GLYPH_CREATE_FILE} />
				</Pending_Button>
				<Pending_Button
					pending={TODO_create_folder_pending}
					attrs={{class: 'plain compact'}}
					title="create folder in {zzz.zzz_dir_pathname}"
					onclick={create_folder}
				>
					<Glyph_Icon icon={GLYPH_CREATE_FOLDER} />
				</Pending_Button>
			</div>
		</div>
		{#if sorted_files.length === 0}
			{#if empty}
				{@render empty()}
			{:else}
				<div class="p_xs font_mono">[no files available]</div>
			{/if}
		{:else}
			<ul class="unstyled">
				{#each sorted_files as file (file.id)}
					{@const selected = diskfiles.selected_file_id === file.id}
					<li transition:slide class:selected>
						<Diskfile_List_Item
							diskfile={file}
							{selected}
							onclick={() => zzz.url_params.update_url('file', file.id)}
						/>
					</li>
				{/each}
			</ul>
		{/if}
	{/if}
</div>

<style>
	.selected {
		position: sticky;
		top: 0;
		bottom: 0;
		background-color: var(--bg); /* TODO needs to be opaque but this is a hack */
	}
</style>
