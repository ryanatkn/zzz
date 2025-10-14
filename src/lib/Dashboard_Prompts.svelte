<script lang="ts">
	import {fade} from 'svelte/transition';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import {random_item} from '@ryanatkn/belt/random.js';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import Part_View from '$lib/Part_View.svelte';
	import {
		GLYPH_PART,
		GLYPH_ADD,
		GLYPH_PROMPT,
		GLYPH_REMOVE,
		GLYPH_DELETE,
		GLYPH_FILE,
		GLYPH_SORT,
	} from '$lib/glyphs.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import Prompt_Stats from '$lib/Prompt_Stats.svelte';
	import Part_List from '$lib/Part_List.svelte';
	import Content_Preview from '$lib/Content_Preview.svelte';
	import {Part} from '$lib/part.svelte.js';
	import Prompt_Contextmenu from '$lib/Prompt_Contextmenu.svelte';
	import Diskfile_Picker_Dialog from '$lib/Diskfile_Picker_Dialog.svelte';
	import Prompt_List from '$lib/Prompt_List.svelte';
	import Editable_Text from '$lib/Editable_Text.svelte';
	import Tutorial_For_Database from '$lib/Tutorial_For_Database.svelte';
	import Tutorial_For_Prompts from '$lib/Tutorial_For_Prompts.svelte';
	import {DURATION_SM} from '$lib/helpers.js';

	const app = frontend_context.get();

	// TODO hovering/selecting parts should show them hovered/selected in both the grid and list

	// TODO clicking the parts should select them, and then selected one should show its name input (or just on hover/tap? what signifier?)

	// TODO history of prompt states (opt in snapshots? also autosave?) using cell builtins/helpers, like file state but generalized for all cells? the json-based, set_json stuff

	let show_diskfile_picker = $state(false);

	// Create and add a Text part
	const add_text_part = () => {
		if (!app.prompts.selected) return;

		const part = Part.create(app, {
			type: 'text',
			content: '',
		});

		app.prompts.selected.add_part(part);
	};

	// Create and add a Diskfile part
	const add_diskfile_part = () => {
		if (!app.prompts.selected) return;

		// Show the diskfile picker dialog
		show_diskfile_picker = true;
	};

	// TODO refactor, maybe move the nav and init logic to `Prompts`?
	const create_prompt = async () => {
		const prompt = app.prompts.add();
		await app.prompts.navigate_to(prompt.id);
	};
</script>

<div class="display_flex width_100 height_100">
	<div class="column_fixed">
		<div class="p_sm pl_0">
			<div class="row gap_xs2 mb_xs pl_xs2">
				<button type="button" class="plain width_100 justify_content_start" onclick={create_prompt}>
					<Glyph glyph={GLYPH_ADD} />&nbsp; new prompt
				</button>
				{#if app.prompts.items.size > 1}
					<button
						type="button"
						class="plain compact selectable deselectable"
						class:selected={app.prompts.show_sort_controls}
						title="toggle sort controls"
						onclick={() => app.prompts.toggle_sort_controls()}
					>
						<Glyph glyph={GLYPH_SORT} />
					</button>
				{/if}
			</div>
			<Prompt_List />
		</div>
		<Tutorial_For_Database />
		<Tutorial_For_Prompts />
	</div>

	{#if app.prompts.selected}
		<Prompt_Contextmenu prompt={app.prompts.selected}>
			<div class="column_fixed pr_sm">
				<section class="column_section">
					<div class="font_size_lg display_flex align_items_center">
						<Glyph glyph={GLYPH_PROMPT} />
						<Editable_Text bind:value={app.prompts.selected.name} />
					</div>
					<div class="column">
						<small>created {app.prompts.selected.created_formatted_short_date}</small>
						<small>
							{app.prompts.selected.parts.length}
							part{#if app.prompts.selected.parts.length !== 1}s{/if}
						</small>
					</div>
					<div class="row gap_xs py_xs">
						<Copy_To_Clipboard text={app.prompts.selected.content} attrs={{class: 'plain'}} />
						<div class="flex_1">
							<Prompt_Stats prompt={app.prompts.selected} />
						</div>
						<Confirm_Button
							onconfirm={() => app.prompts.selected && app.prompts.remove(app.prompts.selected)}
							title="delete prompt {'"' + app.prompts.selected.name + '"'}"
							class="plain icon_button"
						>
							<Glyph glyph={GLYPH_DELETE} />
							{#snippet popover_button_content()}<Glyph glyph={GLYPH_DELETE} />{/snippet}
						</Confirm_Button>
					</div>
					<Content_Preview content={app.prompts.selected.content} />
				</section>
				<section class="column_section">
					<header class="font_size_lg mb_lg"><Glyph glyph={GLYPH_PART} /> parts</header>
					<Part_List
						parts={app.prompts.selected.parts}
						prompt={app.prompts.selected}
						onreorder={(from_index, to_index) => {
							app.prompts.selected?.reorder_parts(from_index, to_index);
						}}
					/>
				</section>
			</div>

			<div class="column_fluid">
				<div class="column_bg_1 column gap_md p_sm">
					<div class="display_flex justify_content_space_between">
						<div class="display_flex flex_wrap_wrap gap_xs">
							<button type="button" class="plain font_size_sm" onclick={add_text_part}>
								<div class="row white_space_nowrap">
									<Glyph glyph={GLYPH_PART} />&nbsp; add text
								</div>
							</button>
							<button
								type="button"
								class="plain font_size_sm"
								onclick={add_diskfile_part}
								disabled={!app.diskfiles.items.size}
							>
								<div class="row white_space_nowrap">
									<Glyph glyph={GLYPH_FILE} />&nbsp; add file
								</div>
							</button>
							<Confirm_Button
								onconfirm={() => app.prompts.selected?.remove_all_parts()}
								disabled={!app.prompts.selected.parts.length}
								class="plain font_size_sm"
							>
								<div class="row white_space_nowrap">
									<Glyph glyph={GLYPH_REMOVE} />&nbsp; remove all
								</div>
							</Confirm_Button>
						</div>
					</div>
					<ul
						class="unstyled display_grid gap_md"
						style:grid-template-columns="repeat(auto-fill, minmax(300px, 1fr))"
					>
						{#each app.prompts.selected.parts as part (part.id)}
							<li in:fade={{duration: DURATION_SM}}>
								<!-- the extra wrapper makes the grid items not stretch vertically -->
								<div class="bg border_radius_xs p_sm">
									<Part_View {part} />
								</div>
							</li>
						{/each}
					</ul>
				</div>
			</div>
		</Prompt_Contextmenu>
	{:else if app.prompts.items.size}
		<div class="box height_100 flex_1" in:fade={{duration: DURATION_SM}}>
			<p>
				select a prompt from the list or <button
					type="button"
					class="inline color_d"
					onclick={create_prompt}>create one</button
				>
				or
				<button
					type="button"
					class="inline color_f"
					onclick={async () => {
						const prompt = random_item(app.prompts.ordered_items);
						await app.prompts.navigate_to(prompt.id);
					}}>go fish</button
				>?
			</p>
		</div>
	{:else}
		<div class="box height_100 flex_1" in:fade={{duration: DURATION_SM}}>
			<p>
				no prompts yet, <button type="button" class="inline color_d" onclick={create_prompt}
					>create a new prompt</button
				>?
			</p>
		</div>
	{/if}
</div>

<Diskfile_Picker_Dialog
	bind:show={show_diskfile_picker}
	onpick={(diskfile) => {
		if (!app.prompts.selected || !diskfile) return false;

		const part = Part.create(app, {
			type: 'diskfile',
			path: diskfile.path,
		});

		app.prompts.selected.add_part(part);
		return true;
	}}
/>
