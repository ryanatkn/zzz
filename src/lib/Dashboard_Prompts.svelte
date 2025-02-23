<script lang="ts">
	import {slide, scale} from 'svelte/transition';
	import {format} from 'date-fns';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Nav_Link from '$lib/Nav_Link.svelte';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import {GLYPH_FRAGMENT, GLYPH_PROMPT} from '$lib/constants.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();

	const fragment_textareas = $state<Record<string, HTMLTextAreaElement>>({});

	// TODO BLOCK save both fragments and prompts to the library, right?

	// TODO BLOCK checkbox that toggles a `<File>` block around it, optionally fill input with path
</script>

<div class="dashboard_prompts">
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
				<Confirm_Button
					onclick={() => zzz.prompts.selected?.remove_all_fragments()}
					button_attrs={{disabled: !zzz.prompts.selected.fragments.length, class: 'plain'}}
				>
					🗙 remove all fragments
				</Confirm_Button>
			</div>
			<div class="fragments">
				{#each zzz.prompts.selected.fragments as fragment (fragment.id)}
					<div class="panel p_sm" transition:scale>
						<div class="flex justify_content_space_between mb_sm">
							<h3 class="m_0">{fragment.name}</h3>
						</div>
						<textarea
							class="mb_xs"
							bind:this={fragment_textareas[fragment.id]}
							value={fragment.content}
							oninput={(e) =>
								zzz.prompts.update_fragment_content(fragment.id, e.currentTarget.value)}
						></textarea>
						<div class="flex gap_xs justify_content_space_between">
							<div class="flex gap_xs">
								<Copy_To_Clipboard text={fragment.content} classes="plain" />
								<button
									type="button"
									class="plain"
									onclick={async () => {
										fragment.content += await navigator.clipboard.readText();
										fragment_textareas[fragment.id].focus();
									}}>paste</button
								>
								<button
									type="button"
									class="plain"
									onclick={() => {
										fragment.content = '';
									}}>clear</button
								>
								<!-- TODO undo -->
							</div>
							<Confirm_Button
								onclick={() => zzz.prompts.remove_fragment(fragment.id)}
								button_attrs={{title: `remove fragment ${fragment.id}`}}
							/>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>

	<div class="width_sm column gap_md">
		<div class="panel p_sm">
			<h3 class="mt_0">preview</h3>
			{#if zzz.prompts.selected}
				<div class="preview font_mono p_xs ellipsis">
					{zzz.prompts.selected.value}
				</div>
				<div class="mt_sm flex gap_sm">
					<Copy_To_Clipboard text={zzz.prompts.selected.value} classes="plain" />
					<button type="button" class="plain flex_1">Test</button>
					<button type="button" class="plain flex_1">Save as Template</button>
				</div>
			{/if}
		</div>
		<div class="panel p_sm">
			<h3 class="mt_0">library</h3>
			<menu class="unstyled">
				<li><button type="button" class="plain w_100">System Context</button></li>
				<li><button type="button" class="plain w_100">Task Instructions</button></li>
				<li><button type="button" class="plain w_100">Response Format</button></li>
				<li><button type="button" class="plain w_100">Constraints</button></li>
			</menu>
		</div>
		<div class="panel p_sm">
			<h3 class="mt_0">actions</h3>
			<menu class="unstyled">
				<li><button type="button" class="plain w_100">Export Library</button></li>
				<li><button type="button" class="plain w_100">Import Template</button></li>
				<li><button type="button" class="plain w_100">Share</button></li>
			</menu>
		</div>
	</div>
</div>

<style>
	.dashboard_prompts {
		display: flex;
		align-items: start;
		gap: var(--space_md);
		padding: var(--space_sm);
	}

	.fragments {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: var(--space_md);
	}

	.preview {
		white-space: pre-wrap;
		border: var(--border_width_sm) solid var(--border_color);
		border-radius: var(--radius_xs);
		background: var(--bg_panel_overlay);
		min-height: 100px;
	}

	textarea {
		height: 80px;
	}
</style>
