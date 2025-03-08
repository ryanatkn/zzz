<script lang="ts">
	import {slide, scale, fade} from 'svelte/transition';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import {random_item} from '@ryanatkn/belt/random.js';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Nav_Link from '$lib/Nav_Link.svelte';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import Bit_View from '$lib/Bit_View.svelte';
	import {GLYPH_BIT, GLYPH_PROMPT, GLYPH_REMOVE} from '$lib/glyphs.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import Prompt_Stats from '$lib/Prompt_Stats.svelte';
	import Bit_List from '$lib/Bit_List.svelte';
	import {Reorderable} from '$lib/reorderable.svelte.js';
	import {Scrollable} from '$lib/scrollable.svelte.js';

	const zzz = zzz_context.get();

	const reorderable = new Reorderable();

	const scrollable = new Scrollable();

	// TODO BLOCK integrate with sources like the local filesystem (just the `zzz.files`?)

	// TODO BLOCK save both bits and prompts to the library, right?

	// TODO BLOCK make it have optional attributes like file type

	// TODO BLOCK the dashed pattern state isn't working for the xml tag input or attributes
</script>

<div class="flex w_100 h_100">
	<div class="column_fixed">
		<div class="p_sm">
			<button
				type="button"
				class="plain w_100 justify_content_start"
				onclick={() => {
					const prompt = zzz.prompts.add();
					prompt.add_bit();
				}}
			>
				+ new prompt
			</button>
			<ul
				class="unstyled mt_sm"
				use:reorderable.list={{
					onreorder: (from_index, to_index) => zzz.prompts.reorder_prompts(from_index, to_index),
				}}
			>
				{#each zzz.prompts.items as prompt, i (prompt.id)}
					<li use:reorderable.item={{index: i}}>
						<Nav_Link
							href="#TODO"
							selected={prompt.id === zzz.prompts.selected_id}
							attrs={{
								class: 'justify_content_space_between',
								style: 'min-height: 0;',
								onclick: () => zzz.prompts.select(prompt.id),
							}}
						>
							<div>
								<span class="mr_xs2">{GLYPH_PROMPT}</span>
								<span>{prompt.name}</span>
							</div>
							{#if prompt.bits.length}<small>{prompt.bits.length}</small>{/if}
						</Nav_Link>
					</li>
				{/each}
			</ul>
		</div>
	</div>

	{#if zzz.prompts.selected}
		<div class="column_fixed">
			<div class="p_sm">
				<div class="size_lg"><Glyph_Icon icon={GLYPH_PROMPT} /> prompt</div>
				{#if zzz.prompts.selected}
					<div class="row gap_sm mt_md mb_sm">
						<Copy_To_Clipboard text={zzz.prompts.selected.content} attrs={{class: 'plain'}} />
						<Prompt_Stats prompt={zzz.prompts.selected} />
					</div>
					<pre
						use:scrollable.container
						use:scrollable.target
						class="font_sans size_sm panel px_md py_xs overflow_auto scrollbar_width_thin"
						style:height="300px"
						style:max-height="300px">{zzz.prompts.selected.content}</pre>
					<!-- TODO something like these? -->
					<!-- <div class="mt_sm flex gap_sm justify_content_space_between">
					<div class="flex gap_sm">
						<button type="button" class="plain">save to library</button>
						<button type="button" class="plain">export</button>
					</div>
				</div> -->
				{/if}
			</div>

			<!-- TODO maybe a library panel? could be like brushes -->
			<!-- <div class="panel p_sm">
			<h3 class="mt_0">library</h3>
			<div class="mb_sm">
				<input type="search" placeholder="Search prompts and bits..." class="w_100" />
			</div>
			<menu class="unstyled"> TODO </menu>
			</div> -->
		</div>

		<div class="column_fluid">
			<div class="column fg_1 gap_md p_sm">
				<div class="flex justify_content_space_between">
					<button type="button" class="plain" onclick={() => zzz.prompts.add_bit()}>
						+ add bit
					</button>
					<div class="flex gap_md">
						<!-- Add file toggle -->
						<!-- <label class="flex gap_xs">
						<input type="checkbox" bind:checked={bit.file_path !== null} />
						Is File
					</label> -->
						<!-- File path input -->
						<!-- {#if bit.file_path !== null}
						<input placeholder="file path (optional)" bind:value={bit.file_path} />
					{/if} -->
						<Confirm_Button
							onclick={() => zzz.prompts.selected?.remove_all_bits()}
							attrs={{disabled: !zzz.prompts.selected.bits.length, class: 'plain'}}
						>
							{GLYPH_REMOVE} remove all bits
						</Confirm_Button>
					</div>
				</div>
				<ul
					class="unstyled grid gap_md"
					style:grid-template-columns="repeat(auto-fill, minmax(var(--width_sm), 1fr))"
				>
					{#each zzz.prompts.selected.bits as bit (bit.id)}
						<li>
							<div class="bg radius_xs p_sm" transition:scale>
								<Bit_View {bit} prompts={zzz.prompts} />
							</div>
						</li>
					{/each}
				</ul>
			</div>
		</div>

		<div class="column_fixed" in:slide>
			<div class="column p_sm">
				<div class="flex justify_content_space_between">
					<div class="size_lg">
						<Glyph_Icon icon={GLYPH_PROMPT} />
						{zzz.prompts.selected.name}
					</div>
					<Confirm_Button
						onclick={() => zzz.prompts.selected && zzz.prompts.remove(zzz.prompts.selected)}
						attrs={{title: `remove Prompt ${zzz.prompts.selected.id}`}}
					/>
				</div>
				<small>{zzz.prompts.selected.id}</small>
				<small>
					{zzz.prompts.selected.bits.length}
					bit{#if zzz.prompts.selected.bits.length !== 1}s{/if}
				</small>
				<small>created {zzz.prompts.selected.created_formatted_short_date}</small>
			</div>
			<div class="p_sm mt_xl3">
				<header class="size_lg mb_lg"><Glyph_Icon icon={GLYPH_BIT} /> bits</header>
				<Bit_List prompt={zzz.prompts.selected} />
			</div>
		</div>
	{:else}
		<div class="flex align_items_center justify_content_center h_100 flex_1" in:fade>
			<p>
				Select a prompt from the list or <button
					type="button"
					class="inline color_d"
					onclick={() => {
						zzz.prompts.add();
					}}>create one</button
				>
				or take a
				<button
					type="button"
					class="inline color_f"
					onclick={() => {
						zzz.prompts.select(random_item(zzz.prompts.items).id);
					}}>random walk</button
				>?
			</p>
		</div>
	{/if}
</div>
