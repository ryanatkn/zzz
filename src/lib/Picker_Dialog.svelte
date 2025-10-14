<script lang="ts" generics="T extends {id: Uuid}">
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import type {ComponentProps} from 'svelte';

	import type {Uuid} from '$lib/zod_helpers.js';
	import Picker from '$lib/Picker.svelte';

	let {
		onpick,
		show = $bindable(false),
		dialog_props,
		...rest
	}: // eslint-disable-next-line @typescript-eslint/no-redundant-type-constituents
	ComponentProps<typeof Picker<T>> & {
		show?: boolean | undefined;
		dialog_props?: Omit_Strict<ComponentProps<typeof Dialog>, 'children'> | undefined;
	} = $props();
</script>

<!-- TODO API with `bind:show` in Fuz dialog? -->
{#if show}
	<Dialog
		{...dialog_props}
		onclose={() => {
			onpick(undefined);
			show = false;
		}}
	>
		<div class="pane p_lg width_upto_md mx_auto">
			<Picker
				{...rest}
				onpick={(item) => {
					// If onpick returns false explicitly, don't close the picker
					const should_close = onpick(item) !== false;
					if (should_close) {
						show = false;
					}
				}}
			/>
		</div>
	</Dialog>
{/if}
