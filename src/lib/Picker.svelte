<script lang="ts" generics="T">
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import type {ComponentProps, Snippet} from 'svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	let {
		onpick,
		show = $bindable(false),
		dialog_props,
		children,
	}: {
		/**
		 * Handle both picking an item or no item.
		 * Return `false` to prevent closing.
		 */
		onpick: (item: T | undefined) => boolean | void; // eslint-disable-line @typescript-eslint/no-redundant-type-constituents
		show?: boolean;
		dialog_props?: Omit_Strict<ComponentProps<typeof Dialog>, 'children'>;
		children: Snippet<[onpick: (item: T | undefined) => void]>; // eslint-disable-line @typescript-eslint/no-redundant-type-constituents
	} = $props();

	// Internal pick handler to manage show state
	// eslint-disable-next-line @typescript-eslint/no-redundant-type-constituents
	const pick = (item: T | undefined) => {
		if (item === undefined) {
			show = false;
			return;
		}

		// If onpick returns false explicitly, don't close the picker
		const should_close = onpick(item) !== false;
		if (should_close) {
			show = false;
		}
	};

	// TODO maybe a popover variant?
</script>

{#if show}
	<Dialog
		{...dialog_props}
		onclose={() => {
			pick(undefined);
			dialog_props?.onclose?.();
		}}
	>
		<div class="pane p_lg">
			{@render children(pick)}
		</div>
	</Dialog>
{/if}
