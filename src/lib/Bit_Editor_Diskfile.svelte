<script lang="ts">
	import {untrack} from 'svelte';

	import {Diskfile_Bit} from '$lib/bit.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import Diskfile_Content_Editor from '$lib/Diskfile_Content_Editor.svelte';
	import Content_Editor from '$lib/Content_Editor.svelte';
	import Diskfile_Actions from '$lib/Diskfile_Actions.svelte';
	import {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';

	interface Props {
		diskfile_bit: Diskfile_Bit;
		show_actions?: boolean;
	}

	const {diskfile_bit, show_actions = true}: Props = $props();
	const zzz = zzz_context.get();

	// Create an editor state if we have a diskfile
	const editor_state = $derived(
		diskfile_bit.diskfile?.id
			? untrack(() => new Diskfile_Editor_State({zzz, diskfile: diskfile_bit.diskfile!}))
			: undefined,
	);
</script>

<div>
	<div class="p_xs bg_1 radius_xs mb_xs">
		<div class="font_mono size_sm mb_xs">
			{diskfile_bit.diskfile?.pathname || 'no file selected'}
		</div>
		{#if diskfile_bit.diskfile}
			<div class="mb_xs">
				<button
					type="button"
					class="plain size_sm"
					onclick={() => {
						zzz.diskfiles.select(diskfile_bit.diskfile?.id);
					}}
				>
					View file
				</button>
			</div>
		{:else}
			<em class="fg_1">File not found or not selected</em>
		{/if}
	</div>

	{#if diskfile_bit.diskfile && editor_state}
		<Diskfile_Content_Editor
			diskfile={diskfile_bit.diskfile}
			{editor_state}
			show_stats={false}
			readonly={!diskfile_bit.diskfile}
		/>

		{#if show_actions && diskfile_bit.diskfile}
			<div class="actions_section mt_xs">
				<Diskfile_Actions diskfile={diskfile_bit.diskfile} {editor_state} />
			</div>
		{/if}
	{:else}
		<Content_Editor
			content={diskfile_bit.content || ''}
			readonly
			placeholder="file not available"
		/>
	{/if}
</div>
