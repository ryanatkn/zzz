<script lang="ts">
	import {scale, fade} from 'svelte/transition';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import {random_item} from '@ryanatkn/belt/random.js';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import Bit_View from '$lib/Bit_View.svelte';
	import {
		GLYPH_BIT,
		GLYPH_ADD,
		GLYPH_PROMPT,
		GLYPH_REMOVE,
		GLYPH_DELETE,
		GLYPH_FILE,
		GLYPH_LIST,
		GLYPH_SORT,
	} from '$lib/glyphs.js';
	import {zzz_context} from '$lib/frontend.svelte.js';
	import Prompt_Stats from '$lib/Prompt_Stats.svelte';
	import Bit_List from '$lib/Bit_List.svelte';
	import Content_Preview from '$lib/Content_Preview.svelte';
	import {Bit} from '$lib/bit.svelte.js';
	import Contextmenu_Prompt from '$lib/Contextmenu_Prompt.svelte';
	import Diskfile_Picker_Dialog from '$lib/Diskfile_Picker_Dialog.svelte';
	import Prompt_List from '$lib/Prompt_List.svelte';

	const app = zzz_context.get();

	// TODO BLOCK clicking the bits should select them, and then selected one should show its name input (or just on hover/tap? what signifier?)

	// TODO BLOCK history of prompt states using cell builtins/helpers, like file state but generalized for all cells? the json-based, set_json stuff

	// TODO BLOCK the reorderable dashed pattern state isn't working for the xml tag input or attributes

	let show_diskfile_picker = $state(false);

	// Create and add a Text bit
	const add_text_bit = () => {
		if (!app.prompts.selected) return;

		const bit = Bit.create(app, {
			type: 'text',
			content: '',
		});

		app.prompts.selected.add_bit(bit);
	};

	// Create and add a Diskfile bit
	const add_diskfile_bit = () => {
		if (!app.prompts.selected) return;

		// Show the diskfile picker dialog
		show_diskfile_picker = true;
	};

	// Create and add a Sequence bit
	const add_sequence_bit = () => {
		if (!app.prompts.selected) return;

		const bit = Bit.create(app, {
			type: 'sequence',
			items: [],
		});

		app.prompts.selected.add_bit(bit);
	};
</script>

<div class="display_flex w_100 h_100">
	<div class="column_fixed">
		<div class="p_sm pl_0">
			<div class="row gap_xs2 mb_xs pl_xs2">
				<button
					type="button"
					class="plain w_100 justify_content_start"
					onclick={async () => {
						const prompt = app.prompts.add();
						prompt.add_bit(Bit.create(app, {type: 'text'}));
						await app.prompts.navigate_to(prompt.id);
					}}
				>
					<Glyph glyph={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> new prompt
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
	</div>

	{#if app.prompts.selected}
		<Contextmenu_Prompt prompt={app.prompts.selected}>
			<div class="column_fixed pr_sm">
				<section class="column_section">
					<div class="font_size_lg">
						<Glyph glyph={GLYPH_PROMPT} />
						{app.prompts.selected.name}
					</div>
					<div class="column">
						<small>created {app.prompts.selected.created_formatted_short_date}</small>
						<small>
							{app.prompts.selected.bits.length}
							bit{#if app.prompts.selected.bits.length !== 1}s{/if}
						</small>
					</div>
					<div class="row gap_xs py_xs">
						<Confirm_Button
							onconfirm={() => app.prompts.selected && app.prompts.remove(app.prompts.selected)}
							position="right"
							attrs={{
								title: `delete prompt ${app.prompts.selected.id}`,
								class: 'plain icon_button',
							}}
						>
							<Glyph glyph={GLYPH_DELETE} />
							{#snippet popover_button_content()}<Glyph glyph={GLYPH_DELETE} />{/snippet}
						</Confirm_Button>
						<Copy_To_Clipboard text={app.prompts.selected.content} attrs={{class: 'plain'}} />
						<Prompt_Stats prompt={app.prompts.selected} />
					</div>
					<Content_Preview content={app.prompts.selected.content} />
				</section>
				<section class="column_section">
					<header class="font_size_lg mb_lg"><Glyph glyph={GLYPH_BIT} /> bits</header>
					<Bit_List
						bits={app.prompts.selected.bits}
						prompt={app.prompts.selected}
						onreorder={(from_index, to_index) => {
							app.prompts.selected?.reorder_bits(from_index, to_index);
						}}
					/>
				</section>
			</div>

			<div class="column_fluid">
				<div class="column_bg_1 column gap_md p_sm">
					<div class="display_flex justify_content_space_between">
						<div class="display_flex flex_wrap gap_xs">
							<button type="button" class="plain font_size_sm" onclick={add_text_bit}>
								<div class="row white_space_nowrap">
									<Glyph glyph={GLYPH_BIT} attrs={{class: 'mr_xs2'}} /> add text
								</div>
							</button>
							<button
								type="button"
								class="plain font_size_sm"
								onclick={add_diskfile_bit}
								disabled={!app.diskfiles.items.size}
							>
								<div class="row white_space_nowrap">
									<Glyph glyph={GLYPH_FILE} attrs={{class: 'mr_xs2'}} /> add file
								</div>
							</button>
							<button type="button" class="plain font_size_sm" onclick={add_sequence_bit}>
								<div class="row white_space_nowrap">
									<Glyph glyph={GLYPH_LIST} attrs={{class: 'mr_xs2'}} /> add sequence
								</div>
							</button>
							<Confirm_Button
								onconfirm={() => app.prompts.selected?.remove_all_bits()}
								attrs={{disabled: !app.prompts.selected.bits.length, class: 'plain font_size_sm'}}
							>
								<div class="row white_space_nowrap">
									<Glyph glyph={GLYPH_REMOVE} attrs={{class: 'mr_xs2'}} /> remove all
								</div>
							</Confirm_Button>
						</div>
					</div>
					<ul
						class="unstyled display_grid gap_md"
						style:grid-template-columns="repeat(auto-fill, minmax(300px, 1fr))"
					>
						{#each app.prompts.selected.bits as bit (bit.id)}
							<li in:scale>
								<!-- the extra wrapper makes the grid items not stretch vertically -->
								<div class="bg border_radius_xs p_sm">
									<Bit_View {bit} />
								</div>
							</li>
						{/each}
					</ul>
				</div>
			</div>
		</Contextmenu_Prompt>
	{:else if app.prompts.items.size}
		<div class="display_flex align_items_center justify_content_center h_100 flex_1" in:fade>
			<p>
				select a prompt from the list or <button
					type="button"
					class="inline color_d"
					onclick={() => {
						app.prompts.add();
					}}>create one</button
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
		<div class="display_flex align_items_center justify_content_center h_100 flex_1" in:fade>
			<p>
				no prompts yet, <button
					type="button"
					class="inline color_d"
					onclick={() => {
						app.prompts.add();
					}}>create a new prompt</button
				>?
			</p>
		</div>
	{/if}
</div>

<Diskfile_Picker_Dialog
	bind:show={show_diskfile_picker}
	onpick={(diskfile) => {
		if (!app.prompts.selected || !diskfile) return false;

		const bit = Bit.create(app, {
			type: 'diskfile',
			path: diskfile.path,
		});

		app.prompts.selected.add_bit(bit);
		return true;
	}}
/>
