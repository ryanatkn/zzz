<script lang="ts">
	import {scale, fade} from 'svelte/transition';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import {random_item} from '@ryanatkn/belt/random.js';
	import {goto} from '$app/navigation';
	import {base} from '$app/paths';

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
	import {zzz_context} from '$lib/zzz.svelte.js';
	import Prompt_Stats from '$lib/Prompt_Stats.svelte';
	import Bit_List from '$lib/Bit_List.svelte';
	import Content_Preview from '$lib/Content_Preview.svelte';
	import {Bit} from '$lib/bit.svelte.js';
	import Contextmenu_Prompt from '$lib/Contextmenu_Prompt.svelte';
	import Diskfile_Picker from '$lib/Diskfile_Picker.svelte';
	import Prompt_List from '$lib/Prompt_List.svelte';

	const zzz = zzz_context.get();

	// TODO BLOCK clicking the bits should select them, and then selected one should show its name input (or just on hover/tap? what signifier?)

	// TODO BLOCK history of prompt states using cell builtins/helpers, like file state but generalized for all cells? the json-based, set_json stuff

	// TODO BLOCK the reorderable dashed pattern state isn't working for the xml tag input or attributes

	let show_diskfile_picker = $state(false);

	// Create and add a Text bit
	const add_text_bit = () => {
		if (!zzz.prompts.selected) return;

		const bit = Bit.create(zzz, {
			type: 'text',
			content: '',
		});

		zzz.prompts.selected.add_bit(bit);
	};

	// Create and add a Diskfile bit
	const add_diskfile_bit = () => {
		if (!zzz.prompts.selected) return;

		// Show the diskfile picker dialog
		show_diskfile_picker = true;
	};

	// Create and add a Sequence bit
	const add_sequence_bit = () => {
		if (!zzz.prompts.selected) return;

		const bit = Bit.create(zzz, {
			type: 'sequence',
			items: [],
		});

		zzz.prompts.selected.add_bit(bit);
	};
</script>

<div class="flex w_100 h_100">
	<div class="column_fixed">
		<div class="p_sm pl_0">
			<div class="row gap_xs2 mb_xs pl_xs2">
				<button
					type="button"
					class="plain w_100 justify_content_start"
					onclick={() => {
						const prompt = zzz.prompts.add();
						prompt.add_bit(Bit.create(zzz, {type: 'text'}));
						void goto(`${base}/prompts/${prompt.id}`);
					}}
				>
					<Glyph text={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> new prompt
				</button>
				{#if zzz.prompts.items.size > 1}
					<button
						type="button"
						class="plain compact selectable deselectable"
						class:selected={zzz.prompts.show_sort_controls}
						title="toggle sort controls"
						onclick={() => zzz.prompts.toggle_sort_controls()}
					>
						<Glyph text={GLYPH_SORT} />
					</button>
				{/if}
			</div>
			<Prompt_List />
		</div>
	</div>

	{#if zzz.prompts.selected}
		<Contextmenu_Prompt prompt={zzz.prompts.selected}>
			<div class="column_fixed pr_sm">
				<section class="column_section">
					<div class="size_lg">
						<Glyph text={GLYPH_PROMPT} />
						{zzz.prompts.selected.name}
					</div>
					<div class="column">
						<small>created {zzz.prompts.selected.created_formatted_short_date}</small>
						<small>
							{zzz.prompts.selected.bits.length}
							bit{#if zzz.prompts.selected.bits.length !== 1}s{/if}
						</small>
					</div>
					<div class="row gap_xs py_xs">
						<Confirm_Button
							onconfirm={() => zzz.prompts.selected && zzz.prompts.remove(zzz.prompts.selected)}
							position="right"
							attrs={{
								title: `delete prompt ${zzz.prompts.selected.id}`,
								class: 'plain icon_button',
							}}
						>
							{GLYPH_DELETE}
							{#snippet popover_button_content()}{GLYPH_DELETE}{/snippet}
						</Confirm_Button>
						<Copy_To_Clipboard text={zzz.prompts.selected.content} attrs={{class: 'plain'}} />
						<Prompt_Stats prompt={zzz.prompts.selected} />
					</div>
					<Content_Preview content={zzz.prompts.selected.content} />
				</section>
				<section class="column_section">
					<header class="size_lg mb_lg"><Glyph text={GLYPH_BIT} /> bits</header>
					<Bit_List
						bits={zzz.prompts.selected.bits}
						prompt={zzz.prompts.selected}
						onreorder={(from_index, to_index) => {
							zzz.prompts.selected?.reorder_bits(from_index, to_index);
						}}
					/>
				</section>
			</div>

			<div class="column_fluid">
				<div class="column_bg_1 column gap_md p_sm">
					<div class="flex justify_content_space_between">
						<div class="flex flex_wrap gap_xs">
							<button type="button" class="plain size_sm" onclick={add_text_bit}>
								<div class="row white_space_nowrap">
									<Glyph text={GLYPH_BIT} attrs={{class: 'mr_xs2'}} /> add text
								</div>
							</button>
							<button
								type="button"
								class="plain size_sm"
								onclick={add_diskfile_bit}
								disabled={!zzz.diskfiles.items.size}
							>
								<div class="row white_space_nowrap">
									<Glyph text={GLYPH_FILE} attrs={{class: 'mr_xs2'}} /> add file
								</div>
							</button>
							<button type="button" class="plain size_sm" onclick={add_sequence_bit}>
								<div class="row white_space_nowrap">
									<Glyph text={GLYPH_LIST} attrs={{class: 'mr_xs2'}} /> add sequence
								</div>
							</button>
							<Confirm_Button
								onconfirm={() => zzz.prompts.selected?.remove_all_bits()}
								attrs={{disabled: !zzz.prompts.selected.bits.length, class: 'plain size_sm'}}
							>
								<div class="row white_space_nowrap">
									<Glyph text={GLYPH_REMOVE} attrs={{class: 'mr_xs2'}} /> remove all
								</div>
							</Confirm_Button>
						</div>
					</div>
					<ul
						class="unstyled grid gap_md"
						style:grid-template-columns="repeat(auto-fill, minmax(300px, 1fr))"
					>
						{#each zzz.prompts.selected.bits as bit (bit.id)}
							<li in:scale>
								<!-- the extra wrapper makes the grid items not stretch vertically -->
								<div class="bg radius_xs p_sm">
									<Bit_View {bit} />
								</div>
							</li>
						{/each}
					</ul>
				</div>
			</div>
		</Contextmenu_Prompt>
	{:else if zzz.prompts.items.size}
		<div class="flex align_items_center justify_content_center h_100 flex_1" in:fade>
			<p>
				Select a prompt from the list or <button
					type="button"
					class="inline color_d"
					onclick={() => {
						zzz.prompts.add();
					}}>create one</button
				>
				or
				<button
					type="button"
					class="inline color_f"
					onclick={() => {
						const prompt = random_item(zzz.prompts.ordered_items);
						void goto(`${base}/prompts/${prompt.id}`);
					}}>go fish</button
				>?
			</p>
		</div>
	{:else}
		<div class="flex align_items_center justify_content_center h_100 flex_1" in:fade>
			<p>
				no prompts available, <button
					type="button"
					class="inline color_d"
					onclick={() => {
						zzz.prompts.add();
					}}>create one</button
				>?
			</p>
		</div>
	{/if}
</div>

<Diskfile_Picker
	bind:show={show_diskfile_picker}
	onpick={(diskfile) => {
		if (!zzz.prompts.selected || !diskfile) return false;

		const bit = Bit.create(zzz, {
			type: 'diskfile',
			path: diskfile.path,
		});

		zzz.prompts.selected.add_bit(bit);
		return true;
	}}
/>
