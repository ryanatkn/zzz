<script lang="ts">
	import {slide} from 'svelte/transition';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import type {Diskfile_Bit} from '$lib/bit.svelte.js';
	import Bit_Summary from '$lib/Bit_Summary.svelte';

	interface Props {
		diskfile: Diskfile;
	}

	const {diskfile}: Props = $props();
	const zzz = zzz_context.get();

	// Find all diskfile bits that reference this file
	const referenced_by_bits = $derived(
		zzz.bits.items.all.filter(
			(bit): bit is Diskfile_Bit => bit.type === 'diskfile' && bit.path === diskfile.path,
		),
	);

	// Find all prompts that contain these bits
	const referenced_by_prompts = $derived(
		zzz.prompts.items.all.filter((prompt) =>
			prompt.bits.some((bit) => referenced_by_bits.some((ref_bit) => ref_bit.id === bit.id)),
		),
	);
</script>

{#if referenced_by_bits.length > 0}
	<div class="panel p_md" transition:slide>
		<h3 class="mt_0 mb_sm">
			Referenced by {referenced_by_bits.length} bit{referenced_by_bits.length !== 1 ? 's' : ''}
		</h3>

		<div class="column gap_xs">
			{#each referenced_by_bits as bit (bit.id)}
				<div class="bit_reference">
					<Bit_Summary {bit} />

					{#if referenced_by_prompts.length}
						<div class="prompt_refs size_xs mt_xs2">
							<span class="text_color_5"
								>In prompt{referenced_by_prompts.length !== 1 ? 's' : ''}:</span
							>
							{#each referenced_by_prompts.filter( (p) => p.bits.some((b) => b.id === bit.id), ) as prompt}
								<a href="?prompt={prompt.id}" class="prompt_ref">
									{prompt.name}
								</a>
							{/each}
						</div>
					{/if}
				</div>
			{/each}
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
