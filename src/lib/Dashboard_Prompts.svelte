<script lang="ts">
	import {slide, scale} from 'svelte/transition';
	import {format} from 'date-fns';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Nav_Link from '$lib/Nav_Link.svelte';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import Bit_View from '$lib/Bit_View.svelte';
	import {GLYPH_BIT, GLYPH_PROMPT, GLYPH_REMOVE} from '$lib/constants.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import Prompt_Stats from '$lib/Prompt_Stats.svelte';
	import Bit_List from '$lib/Bit_List.svelte';
	import {reorderable_list, reorderable_item} from '$lib/reorderable.svelte.js';

	const zzz = zzz_context.get();

	// TODO BLOCK integrate with sources like the local filesystem (just the `zzz.files`?)

	// TODO BLOCK save both bits and prompts to the library, right?

	// TODO BLOCK make it have optional attributes like file type

	// TODO BLOCK the dashed pattern state isn't working for the xml tag input or attributes

	// TODO BLOCK make the prompt links below reorderable
</script>

<div class="flex align_items_start gap_md p_sm">
	<div class="panel p_sm width_sm">
		{#if zzz.prompts.selected}
			<div class="p_sm bg radius_xs2" transition:slide>
				<div class="column">
					<div class="size_lg">
						<Text_Icon icon={GLYPH_PROMPT} />
						{zzz.prompts.selected.name}
					</div>
					<small>{zzz.prompts.selected.id}</small>
					<small>
						{zzz.prompts.selected.bits.length}
						bit{#if zzz.prompts.selected.bits.length !== 1}s{/if}
					</small>
					<small>created {format(zzz.prompts.selected.created, 'MMM d, p')}</small>
					<div class="flex justify_content_end">
						<Confirm_Button
							onclick={() => zzz.prompts.selected && zzz.prompts.remove(zzz.prompts.selected)}
							attrs={{title: `remove Prompt ${zzz.prompts.selected.id}`}}
						/>
					</div>
				</div>
			</div>
		{/if}
		<button
			type="button"
			class="plain w_100 justify_content_start my_sm"
			onclick={() => {
				const prompt = zzz.prompts.add();
				prompt.add_bit();
			}}
		>
			+ new prompt
		</button>
		<ul
			class="unstyled"
			use:reorderable_list={{
				onreorder: (from_index, to_index) => zzz.prompts.reorder_prompts(from_index, to_index),
			}}
		>
			{#each zzz.prompts.items as prompt, i (prompt.id)}
				<li use:reorderable_item={{index: i}}>
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

	{#if zzz.prompts.selected}
		<div class="width_sm column gap_md">
			<div class="panel p_sm">
				<div class="size_lg"><Text_Icon icon={GLYPH_PROMPT} /> prompt</div>
				{#if zzz.prompts.selected}
					<div class="row gap_sm mt_md mb_sm">
						<Copy_To_Clipboard text={zzz.prompts.selected.content} attrs={{class: 'plain'}} />
						<Prompt_Stats prompt={zzz.prompts.selected} />
					</div>
					<pre class="panel p_xs overflow_auto" style:height="300px" style:max-height="300px">{zzz
							.prompts.selected.content}</pre>
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
	{/if}

	{#if zzz.prompts.selected}
		<div class="panel column gap_md p_sm flex_1">
			<div class="flex justify_content_space_between fg_1 radius_sm">
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
	{/if}

	{#if zzz.prompts.selected}
		<div class="panel p_sm width_sm">
			<header class="size_lg mb_lg"><Text_Icon icon={GLYPH_BIT} /> bits</header>
			<Bit_List prompt={zzz.prompts.selected} />
		</div>
	{/if}
</div>
