<script lang="ts">
	import {slide, scale} from 'svelte/transition';
	import {format} from 'date-fns';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import {print_number_with_separators} from '@ryanatkn/belt/print.js';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Nav_Link from '$lib/Nav_Link.svelte';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import Prompt_Fragment_View from '$lib/Prompt_Fragment_View.svelte';
	import {GLYPH_FRAGMENT, GLYPH_PROMPT} from '$lib/constants.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();

	const fragment_textareas = $state<Record<string, HTMLTextAreaElement>>({});

	// TODO BLOCK save both fragments and prompts to the library, right?
</script>

<div class="flex align_items_start gap_md p_sm">
	<div class="panel p_sm width_sm">
		{#if zzz.prompts.selected}
			<div class="p_sm fg_1 radius_xs2" transition:slide>
				<div class="column">
					<div class="size_lg">
						<Text_Icon icon={GLYPH_PROMPT} />
						{zzz.prompts.selected.name}
					</div>
					<small>{zzz.prompts.selected.id}</small>
					<small>
						{zzz.prompts.selected.fragments.length}
						fragment{#if zzz.prompts.selected.fragments.length !== 1}s{/if}
					</small>
					<small>created {format(zzz.prompts.selected.created, 'MMM d, p')}</small>
					<div class="flex justify_content_end">
						<Confirm_Button
							onclick={() => zzz.prompts.selected && zzz.prompts.remove(zzz.prompts.selected)}
							button_attrs={{title: `remove Prompt ${zzz.prompts.selected.id}`}}
						/>
					</div>
				</div>
			</div>
		{/if}
		<button
			type="button"
			class="plain w_100 justify_content_start"
			onclick={() => zzz.prompts.add()}
		>
			+ new prompt
		</button>
		<menu class="unstyled">
			{#each zzz.prompts.items as prompt (prompt.id)}
				<Nav_Link
					href="#TODO"
					selected={prompt.id === zzz.prompts.selected_id}
					attrs={{
						type: 'button',
						class: 'justify_content_space_between',
						style: 'min-height: 0;',
						onclick: () => zzz.prompts.select(prompt.id),
					}}
				>
					<div>
						<span class="mr_xs2">{GLYPH_PROMPT}</span>
						<small>{prompt.name}</small>
					</div>
					{#if prompt.fragments.length}<small>{prompt.fragments.length}</small>{/if}
				</Nav_Link>
			{/each}
		</menu>
	</div>

	<div class="panel p_sm width_sm">
		<header class="size_lg mb_lg"><Text_Icon icon={GLYPH_FRAGMENT} /> fragments</header>
		<div class="column">
			{#if zzz.prompts.selected}
				{#each zzz.prompts.selected.fragments as fragment (fragment.id)}
					<div class="flex panel px_sm py_xs3 white_space_nowrap size_sm">
						<div>{fragment.name}</div>
						<div class="pl_md ellipsis">{fragment.content}</div>
					</div>
				{/each}
			{/if}
		</div>
	</div>

	<div class="panel p_sm flex_1">
		{#if zzz.prompts.selected}
			<div class="flex justify_content_space_between mb_lg">
				<button type="button" class="plain" onclick={() => zzz.prompts.add_fragment()}>
					+ add fragment
				</button>
				<div class="flex gap_md">
					<!-- Add file toggle -->
					<!-- <label class="flex gap_xs">
						<input type="checkbox" bind:checked={fragment.file_path !== null} />
						Is File
					</label> -->
					<!-- File path input -->
					<!-- {#if fragment.file_path !== null}
						<input type="text" placeholder="file path (optional)" bind:value={fragment.file_path} />
					{/if} -->
					<Confirm_Button
						onclick={() => zzz.prompts.selected?.remove_all_fragments()}
						button_attrs={{disabled: !zzz.prompts.selected.fragments.length, class: 'plain'}}
					>
						🗙 remove all fragments
					</Confirm_Button>
				</div>
			</div>
			<div
				class="grid gap_md"
				style:grid-template-columns="repeat(auto-fill, minmax(var(--width_sm), 1fr))"
			>
				{#each zzz.prompts.selected.fragments as fragment (fragment.id)}
					<div class="panel p_sm" transition:scale>
						<Prompt_Fragment_View {fragment} prompts={zzz.prompts} {fragment_textareas} />
					</div>
				{/each}
			</div>
		{/if}
	</div>

	<div class="width_sm column gap_md">
		<div class="panel p_sm">
			<div class="size_lg"><Text_Icon icon={GLYPH_PROMPT} /> final prompt</div>
			{#if zzz.prompts.selected}
				<div class="row gap_sm mt_md mb_sm">
					<Copy_To_Clipboard text={zzz.prompts.selected.value} classes="plain" />
					<span>{print_number_with_separators(zzz.prompts.selected.length + '', ',')} chars</span>
					<span
						>~{print_number_with_separators(zzz.prompts.selected.token_count + '', ',')} tokens</span
					>
				</div>
				<pre class="panel p_xs overflow_auto" style:height="300px" style:max-height="300px">{zzz
						.prompts.selected.value}</pre>
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
				<input type="search" placeholder="Search prompts and fragments..." class="w_100" />
			</div>
			<menu class="unstyled"> TODO </menu>
		</div> -->
	</div>
</div>
