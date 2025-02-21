<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';
	import ollama from 'ollama/browser';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {Multichat} from '$lib/multichat.svelte.js';
	import Model_Selector from '$lib/Model_Selector.svelte';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import Chat_Tape from '$lib/Chat_Tape.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {SYMBOL_TAPE} from '$lib/constants.js';

	const zzz = zzz_context.get();

	// TODO BLOCK this needs to be persisted state
	const multichat = new Multichat(zzz);
	multichat.add_tape(zzz.models.find((m) => m.name === 'llama3.2:1b')!);
	let main_input = $state('');
	let pending = $state(false);
	let input_el: HTMLTextAreaElement | undefined;

	const send_to_all = async () => {
		if (!count) return;
		const parsed = main_input.trim();
		if (!parsed) {
			input_el?.focus();
			return;
		}
		pending = true;
		const r = await ollama.chat({
			model: 'llama3.2:1b',
			messages: [{role: 'user', content: parsed}],
		});
		console.log(`ollama browser response`, r);
		await multichat.send_to_all(parsed);
		main_input = '';
		pending = false;
	};

	const count = $derived(multichat.tapes.length);

	// TODO BLOCK maybe a mode that allows duplicates by holding a key like shift, but otherwise only setting up 1 tape per model?

	// TODO BLOCK the "send to all" button below could have a sibling that creates a new table for each

	// TODO BLOCK custom buttons section - including quick local, smartest all, all, etc

	// TODO BLOCK make a component for the confirm X on the "remove all tapes" button below

	// TODO BLOCK maybe there should be 2 columns of tags, one to include and one to exclude?
</script>

<div class="multichat">
	<div class="column gap_md">
		<div class="panel p_sm">
			<header class="size_xl">
				<h2 class="mt_0 mb_lg">
					<Text_Icon icon={SYMBOL_TAPE} size="var(--icon_size_sm)" /> tapes
				</h2>
			</header>
			<!-- TODO add user-customizable sets of models -->
			<div class="flex">
				<div class="flex_1 p_xs radius_xs">
					<header class="size_lg text_align_center">add by tag</header>
					<menu class="unstyled column">
						{#each Array.from(zzz.tags) as tag (tag)}
							<button
								type="button"
								class="w_100 size_sm py_xs3 justify_content_space_between plain"
								style:min-height="0"
								onclick={() => {
									multichat.add_tapes_by_model_tag(tag);
								}}
							>
								<span>{tag}</span>
								{#if zzz.models.filter((m) => m.tags.includes(tag)).length}
									<span>{zzz.models.filter((m) => m.tags.includes(tag)).length}</span>
								{/if}
							</button>
						{/each}
					</menu>
				</div>
				<div class="flex_1 p_xs radius_xs fg_1">
					<menu class="unstyled column">
						<header class="size_lg text_align_center">delete by tag</header>
						{#each Array.from(zzz.tags) as tag (tag)}
							{@const tapes_with_tag = multichat.tapes.filter((t) => t.model.tags.includes(tag))}
							<button
								type="button"
								class="w_100 min_height_0 size_sm py_xs3 justify_content_space_between plain"
								style:min-height="0"
								disabled={!tapes_with_tag.length}
								onclick={() => {
									multichat.remove_tapes_by_model_tag(tag);
								}}
							>
								<span>{tag}</span>
								{#if tapes_with_tag.length}
									<span>{tapes_with_tag.length}</span>
								{/if}
							</button>
						{/each}
					</menu>
				</div>
				<!-- TODO add custom buttons -->
			</div>
		</div>
		<div class="panel p_sm">
			<header class="mb_md">
				<h3 class="mt_0">add tape with model</h3>
			</header>
			<Model_Selector onselect={(model) => multichat.add_tape(model)}>
				{#snippet children(model)}
					<div>{multichat.tapes.filter((t) => t.model.name === model.name).length}</div>
				{/snippet}
			</Model_Selector>
		</div>
	</div>
	<div class="panel p_sm flex_1">
		<div class="main_input">
			<textarea
				bind:value={main_input}
				bind:this={input_el}
				placeholder="send to all {count >= 2 ? count + ' ' : ''}tapes..."
			></textarea>
			<Pending_Button {pending} onclick={send_to_all}>
				send to all ({count})
			</Pending_Button>
		</div>
		<div class="my_lg">
			<Confirm_Button
				onclick={() => multichat.remove_all_tapes()}
				button_attrs={{disabled: !count}}
			>
				🗙 <span class="ml_xs">remove all tapes</span>
			</Confirm_Button>
		</div>
		<!-- TODO duplicate tape button -->
		<div class="tapes">
			{#each multichat.tapes as tape (tape.id)}
				<Chat_Tape
					{tape}
					onremove={() => multichat.remove_tape(tape.id)}
					onsend={(input: string) => multichat.send_to_tape(tape.id, input)}
				/>
			{/each}
		</div>
	</div>
</div>

<style>
	.multichat {
		display: flex;
		align-items: start;
		flex: 1;
		gap: var(--space_md);
	}
	.main_input {
		flex: 1;
		display: flex;
		gap: var(--space_xs);
	}
	.main_input textarea {
		flex: 1;
		min-height: 4rem;
		margin-bottom: 0;
	}
	.tapes {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: var(--space_md);
	}
</style>
