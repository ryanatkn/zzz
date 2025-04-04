<script lang="ts">
	import {slide} from 'svelte/transition';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Bit_Summary from '$lib/Bit_Summary.svelte';

	interface Props {
		diskfile: Diskfile;
	}

	const {diskfile}: Props = $props();

	const zzz = zzz_context.get();

	const bit = $derived(diskfile.bit);

	const referenced_by_prompts = $derived(bit ? zzz.prompts.filter_by_bit(bit) : null);
</script>

{#if bit}
	<div class="panel p_md" transition:slide>
		<h3 class="mt_0 mb_sm">Referenced by bit</h3>

		<div class="column gap_xs">
			<div class="bit_reference">
				<Bit_Summary {bit} />

				{#if referenced_by_prompts?.length}
					<div class="prompt_refs size_xs mt_xs2">
						<span class="text_color_5"
							>In prompt{referenced_by_prompts.length !== 1 ? 's' : ''}:</span
						>
						{#each referenced_by_prompts as prompt}
							<a href="?prompt={prompt.id}" class="prompt_ref">
								{prompt.name}
							</a>
						{/each}
					</div>
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	.bit_reference {
		padding: var(--space_xs2);
		background: var(--bg_2);
		border-radius: var(--radius_xs);
	}

	.prompt_refs {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space_xs2);
		align-items: center;
	}

	.prompt_ref {
		padding: var(--space_xs3) var(--space_xs2);
		background: var(--bg_3);
		border-radius: var(--radius_xs);
		text-decoration: none;
		color: inherit;
	}

	.prompt_ref:hover {
		background: var(--bg_4);
	}
</style>
