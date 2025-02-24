<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';
	import ollama from 'ollama/browser';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {Chat} from '$lib/chat.svelte.js';
	import Model_Selector from '$lib/Model_Selector.svelte';
	import Chat_Tape from '$lib/Chat_Tape.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {GLYPH_TAPE, GLYPH_PROMPT} from '$lib/constants.js';
	import {zzz_config} from '$lib/zzz_config.js';
	import Clear_Restore_Button from '$lib/Clear_Restore_Button.svelte';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import Paste_From_Clipboard from '$lib/Paste_From_Clipboard.svelte';

	const zzz = zzz_context.get();

	interface Props {
		chat: Chat;
	}

	const {chat}: Props = $props();

	// TODO BLOCK this needs to be persisted state
	if (chat.tapes.length === 0) {
		const initial_model_names = ['llama3.2:1b', 'qwen2.5:0.5b', 'qwen2.5:1.5b'];
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
	let pending = $state(false); // TODO BLOCK @many this state probably belongs on the `multichat` object
	let main_input_el: HTMLTextAreaElement | undefined;

	const send_to_all = async () => {
		if (!count) return;
		const parsed = main_input.trim();
		if (!parsed) {
			main_input_el?.focus();
			return;
		}
		pending = true;
		const r = await ollama.chat({
			model: zzz_config.bots.namerbot,
			messages: [{role: 'user', content: parsed}],
			options: {temperature: 1}, // TODO BLOCK same options as server (proxy through our endpoint? we still want to be able to separate the Ollama and server endpoints though, not forced through our proxy)
		});
		console.log(`ollama browser response`, r);
		await chat.send_to_all(parsed);
		main_input = '';
		pending = false;
	};

	const count = $derived(chat.tapes.length);

	// TODO BLOCK prompts in a column on the right - custom buttons to do common things, compose them with a textarea with buttons like "fill all" or "fill with tag" or at least drag

	// TODO BLOCK add `presets`  section to the top with the custom buttons/sets (accessible via contextmenu)

	// TODO BLOCK maybe a mode that allows duplicates by holding a key like shift, but otherwise only setting up 1 tape per model?

	// TODO BLOCK the "send to all" button below could have a sibling that creates a new table for each

	// TODO BLOCK custom buttons section - including quick local, smartest all, all, etc

	// TODO BLOCK make a component for the confirm X on the "remove all tapes" button below

	// TODO BLOCK maybe there should be 2 columns of tags, one to include and one to exclude?
</script>

<div class="chat_view">
	<div class="width_sm column gap_md">
		<div class="panel p_sm">
			<header class="mt_0 mb_lg size_lg">{GLYPH_TAPE} tapes</header>
			<p>TODO add buttons with sets</p>
		</div>
		<div class="panel">
			<!-- TODO add user-customizable sets of models -->
			<div class="flex">
				<div class="flex_1 p_xs radius_xs">
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
				<div class="flex_1 p_xs radius_xs fg_1">
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
		<div class="panel p_sm">
			<header class="mb_md mt_0 size_lg">add tape with model</header>
			<Model_Selector onselect={(model) => chat.add_tape(model)}>
				{#snippet children(model)}
					<div>{chat.tapes.filter((t) => t.model.name === model.name).length}</div>
				{/snippet}
			</Model_Selector>
		</div>
	</div>
	<div class="panel p_sm flex_1">
		<div class="flex flex_1">
			<textarea
				class="flex_1 mb_0"
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
		<div class="flex mt_xs">
			<Copy_To_Clipboard text={main_input} classes="plain" />
			<Paste_From_Clipboard
				onpaste={(text) => {
					main_input += text;
					main_input_el?.focus();
				}}
				attrs={{class: 'plain'}}
			/>
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
				🗙 <span class="ml_xs">remove all tapes</span>
			</Confirm_Button>
		</div>
		<!-- TODO duplicate tape button -->
		<div class="tapes mt_lg">
			{#each chat.tapes as tape (tape.id)}
				<Chat_Tape
					{tape}
					onremove={() => chat.remove_tape(tape.id)}
					onsend={(input: string) => chat.send_to_tape(tape.id, input)}
				/>
			{/each}
		</div>
	</div>
	<div class="width_sm column gap_md">
		<div class="panel p_sm">
			<header class="mt_0 mb_lg size_lg">{GLYPH_PROMPT} prompts</header>
			<p>TODO custom prompt buttons</p>
		</div>
	</div>
</div>

<style>
	.chat_view {
		display: flex;
		align-items: start;
		flex: 1;
		gap: var(--space_md);
	}
	.tapes {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: var(--space_md);
	}
</style>
