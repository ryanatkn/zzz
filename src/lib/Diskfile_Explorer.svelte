<script lang="ts">
	import {slide} from 'svelte/transition';
	import type {Snippet} from 'svelte';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';

	import {frontend_context} from '$lib/frontend.svelte.js';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Diskfile_Listitem from '$lib/Diskfile_Listitem.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {
		GLYPH_DIRECTORY,
		GLYPH_CREATE_FILE,
		GLYPH_CREATE_FOLDER,
		GLYPH_SORT,
	} from '$lib/glyphs.js';
	import Sortable_List from '$lib/Sortable_List.svelte';
	import {sort_by_text, sort_by_numeric} from '$lib/sortable.svelte.js';

	interface Props {
		empty?: Snippet | undefined;
	}

	const {empty}: Props = $props();

	const app = frontend_context.get();
	const {diskfiles} = app;
	const {editor} = diskfiles;

	const {zzz_cache_dir} = $derived(app);

	// TODO need awaitable websocket calls?
	const TODO_create_file_pending = false;
	const TODO_create_folder_pending = false;

	// TODO improve UX to not use alert/prompt
	const create_file = () => {
		if (!zzz_cache_dir) {
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
		if (!zzz_cache_dir) {
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
	{#if zzz_cache_dir === undefined}
		<div>&nbsp;</div>
	{:else if zzz_cache_dir === null}
		<div class="row h_input_height"><Pending_Animation /></div>
	{:else}
		<div class="row h_input_height justify_content_space_between px_xs">
			<small class="ellipsis"><Glyph glyph={GLYPH_DIRECTORY} /> {zzz_cache_dir}</small>
			<div class="display_flex gap_xs2">
				<Pending_Button
					pending={TODO_create_file_pending}
					attrs={{class: 'plain compact'}}
					title="create file in {zzz_cache_dir}"
					onclick={create_file}
				>
					<Glyph glyph={GLYPH_CREATE_FILE} />
				</Pending_Button>
				<Pending_Button
					pending={TODO_create_folder_pending}
					attrs={{class: 'plain compact'}}
					title="create folder in {zzz_cache_dir}"
					onclick={create_folder}
				>
					<Glyph glyph={GLYPH_CREATE_FOLDER} />
				</Pending_Button>
				{#if app.diskfiles.items.size > 1}
					<button
						type="button"
						class="plain compact selectable deselectable"
						class:selected={editor.show_sort_controls}
						title="toggle sort controls"
						onclick={() => editor.toggle_sort_controls()}
					>
						<Glyph glyph={GLYPH_SORT} />
					</button>
				{/if}
			</div>
		</div>

		<!-- TODO @many improve efficiency - maybe add `all` back to the base Indexed_Collection, or add an incremental index for this case? -->
		<Sortable_List
			items={diskfiles.items.values}
			show_sort_controls={editor.show_sort_controls}
			sorters={[
				// TODO @many rework API to avoid casting
				sort_by_text<Diskfile>('path_asc', 'path (a-z)', 'path_relative'),
				sort_by_text<Diskfile>('path_desc', 'path (z-a)', 'path_relative', 'desc'),
				sort_by_numeric<Diskfile>('updated_newest', 'updated (latest)', 'updated', 'desc'),
				sort_by_numeric<Diskfile>('updated_oldest', 'updated (past)', 'updated', 'asc'),
				sort_by_numeric<Diskfile>('created_newest', 'created (newest)', 'created', 'desc'),
				sort_by_numeric<Diskfile>('created_oldest', 'created (oldest)', 'created', 'asc'),
			]}
			sort_key_default="path_asc"
			no_items={empty ? undefined : '[no files available]'}
		>
			{#snippet children(diskfile)}
				{@const selected = diskfiles.selected_file_id === diskfile.id}
				<div class="diskfile_listitem_wrapper" class:selected transition:slide>
					<Diskfile_Listitem
						{diskfile}
						{selected}
						onselect={(diskfile, hard) => {
							diskfiles.select(diskfile.id, hard);
						}}
					/>
				</div>
			{/snippet}
		</Sortable_List>

		{#if empty && diskfiles.items.size === 0}
			{@render empty()}
		{/if}
	{/if}
</div>

<style>
	.diskfile_listitem_wrapper {
		position: sticky;
		top: 0;
		bottom: 0;
		background-color: var(--bg); /* TODO needs to be opaque but this is a hack */
	}
</style>
