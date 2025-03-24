<script lang="ts">
	import Picker from '$lib/Picker.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Prompt} from '$lib/prompt.svelte.js';
	import Prompt_Summary from '$lib/Prompt_Summary.svelte';
	import type {Uuid} from '$lib/zod_helpers.js';

	interface Props {
		onpick: (prompt: Prompt | undefined) => boolean | void;
		show?: boolean | undefined;
		filter?: ((prompt: Prompt) => boolean) | undefined;
		exclude_ids?: Array<Uuid> | undefined;
		selected_ids?: Array<Uuid> | undefined;
	}

	let {onpick, show = $bindable(false), filter, exclude_ids = []}: Props = $props();

	const zzz = zzz_context.get();
	const {prompts} = zzz;

	// TODO refactor
	const filtered_prompts = $derived(
		prompts.items.all
			.filter((p) => {
				// First check if the prompt ID is in the exclude list
				if (exclude_ids.includes(p.id)) {
					return false;
				}
				// Then apply the custom filter if provided
				return filter ? filter(p) : true;
			})
			.sort((a, b) => a.name.localeCompare(b.name)),
	);
</script>

<Picker bind:show {onpick}>
	{#snippet children(pick)}
		<h2 class="mt_lg text_align_center">Pick a prompt</h2>
		{#if filtered_prompts.length === 0}
			<div class="p_md">No prompts available</div>
		{:else}
			<ul class="unstyled">
				{#each filtered_prompts as prompt (prompt.id)}
					<li>
						<button
							type="button"
							class="button_list_item compact w_100"
							onclick={() => pick(prompt)}
						>
							<div class="p_xs size_sm">
								<Prompt_Summary {prompt} />
							</div>
						</button>
					</li>
				{/each}
			</ul>
		{/if}
	{/snippet}
</Picker>
