<script lang="ts">
	import {slide} from 'svelte/transition';
	import type {Snippet} from 'svelte';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Diskfile_Listitem from '$lib/Diskfile_Listitem.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_DIRECTORY, GLYPH_CREATE_FILE, GLYPH_CREATE_FOLDER} from '$lib/glyphs.js';
	import Sortable_List from '$lib/Sortable_List.svelte';
	import {sort_by_text} from '$lib/sortable.svelte.js';

	interface Props {
		empty?: Snippet | undefined;
	}

	const {empty}: Props = $props();

	const zzz = zzz_context.get();
	const {diskfiles} = zzz;

	// TODO need awaitable websocket calls?
	const TODO_create_file_pending = false;
	const TODO_create_folder_pending = false;

	// Create a filter for non-external diskfiles
	const non_external_filter = (diskfile: Diskfile): boolean => !diskfile.external;

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
			<small class="ellipsis"><Glyph icon={GLYPH_DIRECTORY} /> {zzz.zzz_dir_pathname}</small>
			<div class="flex gap_xs">
				<Pending_Button
					pending={TODO_create_file_pending}
					attrs={{class: 'plain compact'}}
					title="create file in {zzz.zzz_dir_pathname}"
					onclick={create_file}
				>
					<Glyph icon={GLYPH_CREATE_FILE} />
				</Pending_Button>
				<Pending_Button
					pending={TODO_create_folder_pending}
					attrs={{class: 'plain compact'}}
					title="create folder in {zzz.zzz_dir_pathname}"
					onclick={create_folder}
				>
					<Glyph icon={GLYPH_CREATE_FOLDER} />
				</Pending_Button>
			</div>
		</div>

		<!-- TODO @many why is the cast needed? -->
		<Sortable_List
			items={diskfiles.items}
			filter={non_external_filter}
			show_sort_controls={true}
			sorters={[sort_by_text<Diskfile>('path_asc', 'path (a-z)', 'path_relative')]}
			sort_key_default="path_asc"
			no_items_message={empty ? undefined : '[no files available]'}
		>
			{#snippet children(diskfile)}
				{@const selected = diskfiles.selected_file_id === diskfile.id}
				<div class:selected transition:slide>
					<Diskfile_Listitem
						{diskfile}
						{selected}
						onclick={() => zzz.url_params.update_url('file', diskfile.id)}
					/>
				</div>
			{/snippet}
		</Sortable_List>

		{#if empty && diskfiles.items.all.filter(non_external_filter).length === 0}
			{@render empty()}
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
