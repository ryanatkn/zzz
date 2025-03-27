<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';
	import {slide} from 'svelte/transition';

	import Glyph from '$lib/Glyph.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {Chat} from '$lib/chat.svelte.js';
	import Model_Selector from '$lib/Model_Selector.svelte';
	import Chat_Tape from '$lib/Chat_Tape.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {
		GLYPH_TAPE,
		GLYPH_BIT,
		GLYPH_PROMPT,
		GLYPH_REMOVE,
		GLYPH_CHAT,
		GLYPH_PLACEHOLDER,
		GLYPH_DELETE,
	} from '$lib/glyphs.js';
	import Prompt_List from '$lib/Prompt_List.svelte';
	import Bit_List from '$lib/Bit_List.svelte';
	import Tape_List from '$lib/Tape_List.svelte';
	import Content_Editor from '$lib/Content_Editor.svelte';

	const zzz = zzz_context.get();

	interface Props {
		chat: Chat;
	}

	const {chat}: Props = $props();

	// TODO BLOCK this needs to be persisted state
	if (chat.tapes.length === 0) {
		const initial_model_names = [
			'llama3.2:1b',
			'llama3.2:3b',
			'gemma3:1b',
			'gemma3:4b',
			'qwen2.5:0.5b',
			'qwen2.5:1.5b',
		];
		const initial_models = zzz.models.filter_by_names(initial_model_names);
		if (initial_models) {
			for (const initial_model of initial_models) {
				chat.add_tape(initial_model);
			}
		} else {
			console.error(`model not found: ${zzz.bots.namerbot}`);
		}
	}

	let pending = $state(false); // TODO BLOCK @many this state probably belongs on the `multichat` object
	let main_input_el: {focus: () => void} | undefined;

	const send_to_all = async () => {
		if (!count) return;
		const parsed = chat.main_input.trim();
		if (!parsed) {
			main_input_el?.focus();
			return;
		}
		chat.main_input = '';
		pending = true;
		await chat.send_to_all(parsed);
		pending = false;
	};

	const count = $derived(chat.tapes.length);

	// TODO BLOCK probably put this behind a simplified chat interface with an "advanced" button

	// TODO BLOCK add an enable button/state like with prompt bits

	// TODO BLOCK show a list of tapes in a panel like with prompt bits

	// TODO BLOCK prompts in a column on the right - custom buttons to do common things, compose them with a textarea with buttons like "fill all" or "fill with tag" or at least drag

	// TODO BLOCK add `presets`  section to the top with the custom buttons/sets (accessible via contextmenu)

	// TODO BLOCK maybe a mode that allows duplicates by holding a key like shift, but otherwise only setting up 1 tape per model?

	// TODO BLOCK custom buttons section - including quick local, smartest all, all, etc

	// TODO BLOCK remove all tapes needs to open to the right of the button

	const tags = $derived(Array.from(zzz.tags)); // TODO BLOCK refactor, maybe `zzz.tags_array`? or `zzz.tags.all`

	const selected_chat = $derived(zzz.chats.selected);
</script>

<div class="flex_1 h_100 flex align_items_start">
	<div class="column_fixed column">
		<div class="column gap_md">
			{#if selected_chat}
				<div transition:slide>
					<div class="column p_sm">
						<!-- TODO needs work -->
						<div class="flex justify_content_space_between">
							<div class="size_lg">
								<Glyph icon={GLYPH_CHAT} />
								{selected_chat.name}
							</div>
						</div>
						<div class="row">
							<Confirm_Button
								onconfirm={() => zzz.chats.selected_id && zzz.chats.remove(zzz.chats.selected_id)}
								attrs={{title: `delete chat "${selected_chat.name}"`, class: 'plain'}}
							>
								{GLYPH_DELETE}
								{#snippet popover_button_content()}{GLYPH_DELETE}{/snippet}
							</Confirm_Button>
						</div>
						<div class="font_mono">
							<small>{selected_chat.id}</small>
							<small title={selected_chat.created_formatted_date}
								>created {selected_chat.created_formatted_short_date}</small
							>
							<small>
								{selected_chat.tapes.length}
								tape{#if selected_chat.tapes.length !== 1}s{/if}
							</small>
						</div>
					</div>
				</div>
			{/if}
			<div class="p_sm">
				<header class="mt_0 mb_lg size_lg"><Glyph icon={GLYPH_TAPE} /> tapes</header>
				<Tape_List {chat} />
			</div>
			<div class="p_sm">
				<header class="mt_0 mb_lg size_lg"><Glyph icon={GLYPH_PROMPT} /> prompts</header>
				<Prompt_List {chat} />
			</div>
			<!-- TODO maybe show `Bit_List` with the `prompt bits` header here in -->
			<div class="p_sm">
				<header class="mt_0 mb_lg size_lg"><Glyph icon={GLYPH_BIT} /> all bits</header>
				<Bit_List bits={chat.bits_array} />
			</div>
		</div>
	</div>
	<div class="column_fluid">
		<div class="column_bg_1 p_sm">
			<Content_Editor
				bind:this={main_input_el}
				bind:content={chat.main_input}
				token_count={chat.main_input_token_count}
				placeholder="{GLYPH_PLACEHOLDER} to {count}"
				show_actions
				show_stats
			>
				<Pending_Button
					{pending}
					onclick={send_to_all}
					disabled={!count ? true : undefined}
					attrs={{class: 'plain'}}
				>
					send to {count}
				</Pending_Button>
			</Content_Editor>

			<div class="mt_lg">
				<Confirm_Button
					onconfirm={() => chat.remove_all_tapes()}
					position="right"
					attrs={{disabled: !count, class: 'plain'}}>{GLYPH_REMOVE} remove all</Confirm_Button
				>
			</div>
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
		<div class="fg_1">
			<!-- TODO add user-customizable sets of models -->
			<div class="flex">
				<div class="flex_1 p_xs">
					<header class="size_lg text_align_center mb_xs">add by tag</header>
					<menu class="unstyled column">
						{#each tags as tag (tag)}
							<button
								type="button"
								class="w_100 size_sm py_xs3 justify_content_space_between plain radius_xs font_weight_600"
								style:min-height="0"
								onclick={() => {
									chat.add_tapes_by_model_tag(tag);
								}}
							>
								<span>{tag}</span>
								{#if zzz.models.items.all.filter((m) => m.tags.includes(tag)).length}
									<span>{zzz.models.items.all.filter((m) => m.tags.includes(tag)).length}</span>
								{/if}
							</button>
						{/each}
					</menu>
				</div>
				<div class="flex_1 p_xs fg_1">
					<header class="size_lg text_align_center mb_xs">remove by tag</header>
					<menu class="unstyled column">
						{#each tags as tag (tag)}
							{@const tapes_with_tag = chat.tapes.filter((t) => t.model.tags.includes(tag))}
							<Confirm_Button
								attrs={{
									disabled: !tapes_with_tag.length,
									class:
										'w_100 size_sm py_xs3 justify_content_space_between plain radius_xs font_weight_600',
									style: 'min-height: 0;',
								}}
								onconfirm={() => {
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
			<header class="mb_md size_lg">add by model</header>
			<Model_Selector onselect={(model) => chat.add_tape(model)}>
				{#snippet children(model)}
					<div>{chat.tapes.filter((t) => t.model.name === model.name).length}</div>
				{/snippet}
			</Model_Selector>
		</div>
	</div>
</div>

<style>
	.tapes {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: var(--space_md);
	}
</style>
