<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import Paste_From_Clipboard from '@ryanatkn/fuz/Paste_From_Clipboard.svelte';
	import {encode as tokenize} from 'gpt-tokenizer';
	import {slide} from 'svelte/transition';

	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {Chat} from '$lib/chat.svelte.js';
	import Model_Selector from '$lib/Model_Selector.svelte';
	import Chat_Tape from '$lib/Chat_Tape.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_TAPE, GLYPH_PROMPT, GLYPH_REMOVE, GLYPH_PASTE, GLYPH_CHAT} from '$lib/glyphs.js';
	import {zzz_config} from '$lib/zzz_config.js';
	import Clear_Restore_Button from '$lib/Clear_Restore_Button.svelte';
	import Bit_Stats from '$lib/Bit_Stats.svelte';
	import Prompt_List from '$lib/Prompt_List.svelte';
	import Tape_List from '$lib/Tape_List.svelte';

	const zzz = zzz_context.get();

	interface Props {
		chat: Chat;
	}

	const {chat}: Props = $props();

	// TODO BLOCK this needs to be persisted state
	if (chat.tapes.length === 0) {
		const initial_model_names = ['llama3.2:1b', 'llama3.2:3b', 'qwen2.5:0.5b', 'qwen2.5:1.5b'];
		const initial_models = zzz.models.filter_by_names(initial_model_names);
		if (initial_models) {
			for (const initial_model of initial_models) {
				chat.add_tape(initial_model);
			}
		} else {
			console.error(`model not found: ${zzz_config.bots.namerbot}`);
		}
	}
	let main_input = $state(''); // TODO BLOCK @many this state probably belongs on the `multichat` object
	const main_input_tokens = $derived(tokenize(main_input));

	let pending = $state(false); // TODO BLOCK @many this state probably belongs on the `multichat` object
	let main_input_el: HTMLTextAreaElement | undefined;

	const send_to_all = async () => {
		if (!count) return;
		const parsed = main_input.trim();
		if (!parsed) {
			main_input_el?.focus();
			return;
		}
		main_input = '';
		pending = true;
		await chat.send_to_all(parsed);
		pending = false;
	};

	const count = $derived(chat.tapes.length);

	// TODO BLOCK add an enable button/state like with prompt bits

	// TODO BLOCK show a list of tapes in a panel like with prompt bits

	// TODO BLOCK prompts in a column on the right - custom buttons to do common things, compose them with a textarea with buttons like "fill all" or "fill with tag" or at least drag

	// TODO BLOCK add `presets`  section to the top with the custom buttons/sets (accessible via contextmenu)

	// TODO BLOCK maybe a mode that allows duplicates by holding a key like shift, but otherwise only setting up 1 tape per model?

	// TODO BLOCK custom buttons section - including quick local, smartest all, all, etc

	// TODO BLOCK remove all tapes needs to open to the right of the button
</script>

<div class="flex_1 h_100 flex align_items_start">
	<div class="column_fixed column">
		<div class="fg_1">
			<!-- TODO add user-customizable sets of models -->
			<div class="flex">
				<div class="flex_1 p_xs">
					<header class="size_lg text_align_center mb_xs">add by tag</header>
					<menu class="unstyled column">
						{#each Array.from(zzz.tags) as tag (tag)}
							<button
								type="button"
								class="w_100 size_sm py_xs3 justify_content_space_between plain radius_xs font_weight_600"
								style:min-height="0"
								onclick={() => {
									chat.add_tapes_by_model_tag(tag);
								}}
							>
								<span>{tag}</span>
								{#if zzz.models.items.filter((m) => m.tags.includes(tag)).length}
									<span>{zzz.models.items.filter((m) => m.tags.includes(tag)).length}</span>
								{/if}
							</button>
						{/each}
					</menu>
				</div>
				<div class="flex_1 p_xs fg_1">
					<header class="size_lg text_align_center mb_xs">remove by tag</header>
					<menu class="unstyled column">
						{#each Array.from(zzz.tags) as tag (tag)}
							{@const tapes_with_tag = chat.tapes.filter((t) => t.model.tags.includes(tag))}
							<Confirm_Button
								attrs={{
									disabled: !tapes_with_tag.length,
									class:
										'w_100 size_sm py_xs3 justify_content_space_between plain radius_xs font_weight_600',
									style: 'min-height: 0;',
								}}
								onclick={() => {
									chat.remove_tapes_by_model_tag(tag);
								}}
							>
								<span>{tag}</span>
								{#if tapes_with_tag.length}
									<span>{tapes_with_tag.length}</span>
								{/if}
							</Confirm_Button>
						{/each}
					</menu>
				</div>
				<!-- TODO add custom buttons -->
			</div>
		</div>
		<div class="fg_1 p_sm">
			<header class="mb_md size_lg">add tape with model</header>
			<Model_Selector onselect={(model) => chat.add_tape(model)}>
				{#snippet children(model)}
					<div>{chat.tapes.filter((t) => t.model.name === model.name).length}</div>
				{/snippet}
			</Model_Selector>
		</div>
	</div>
	<div class="column_fluid">
		<div class="column_bg_1 p_sm">
			<div class="flex gap_xs2 flex_1 mb_xs">
				<textarea
					class="plain flex_1 mb_0"
					bind:value={main_input}
					bind:this={main_input_el}
					placeholder="send to all {count >= 2 ? count + ' ' : ''}tapes..."
				></textarea>
				<Pending_Button
					{pending}
					onclick={send_to_all}
					disabled={!count ? true : undefined}
					attrs={{class: 'plain'}}
				>
					send to all ({count})
				</Pending_Button>
			</div>
			<Bit_Stats length={main_input.length} token_count={main_input_tokens.length} />
			<div class="flex mt_xs">
				<Copy_To_Clipboard text={main_input} attrs={{class: 'plain'}} />
				<Paste_From_Clipboard
					onpaste={(text) => {
						main_input += text;
						main_input_el?.focus();
					}}
					attrs={{class: 'plain icon_button size_lg', title: 'paste'}}
					>{GLYPH_PASTE}</Paste_From_Clipboard
				>
				<Clear_Restore_Button
					value={main_input}
					onchange={(value) => {
						main_input = value;
					}}
				/>
			</div>
			<div class="mt_lg">
				<Confirm_Button
					onclick={() => chat.remove_all_tapes()}
					attrs={{disabled: !count, class: 'plain'}}
				>
					{GLYPH_REMOVE} <span class="ml_xs">remove all tapes</span>
				</Confirm_Button>
			</div>
			<!-- TODO duplicate tape button -->
			<ul class="tapes unstyled mt_lg">
				{#each chat.tapes as tape (tape.id)}
					<li>
						<Chat_Tape
							{tape}
							onremove={() => chat.remove_tape(tape.id)}
							onsend={(input: string) => chat.send_to_tape(tape.id, input)}
						/>
					</li>
				{/each}
			</ul>
		</div>
	</div>
	<div class="column_fixed">
		<div class="column gap_md">
			{#if zzz.chats.selected}
				<div transition:slide>
					<div class="column p_sm">
						<!-- TODO needs work -->
						<div class="flex justify_content_space_between mb_md">
							<div class="size_lg">
								<Glyph_Icon icon={GLYPH_CHAT} />
								{zzz.chats.selected.name}
							</div>
							<Confirm_Button
								onclick={() => zzz.chats.selected && zzz.chats.remove(zzz.chats.selected)}
								attrs={{title: `delete chat "${zzz.chats.selected.name}"`}}
							/>
						</div>
						<small>{zzz.chats.selected.id}</small>
						<small title={zzz.chats.selected.created_formatted_date}
							>created {zzz.chats.selected.created_formatted_short_date}</small
						>
						<small>
							{zzz.chats.selected.tapes.length}
							tape{#if zzz.chats.selected.tapes.length !== 1}s{/if}
						</small>
					</div>
				</div>
			{/if}
			<div class="p_sm">
				<header class="mt_0 mb_lg size_lg"><Glyph_Icon icon={GLYPH_TAPE} /> tapes</header>
				<Tape_List {chat} />
			</div>
			<div class="p_sm">
				<header class="mt_0 mb_lg size_lg"><Glyph_Icon icon={GLYPH_PROMPT} /> prompts</header>
				<Prompt_List {chat} />
			</div>
		</div>
	</div>
</div>

<style>
	.tapes {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(var(--width_sm), 1fr));
		gap: var(--space_md);
	}
</style>
