<script lang="ts">
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import type {ComponentProps, Snippet} from 'svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import Model_Picker from '$lib/Model_Picker.svelte';
	import type {Model} from '$lib/model.svelte.js';

	interface Props extends Omit_Strict<ComponentProps<typeof Dialog>, 'children'> {
		show: boolean;
		onpick: (model: Model | undefined) => boolean | void;
		filter?: ((model: Model) => boolean) | undefined;
		children?: Snippet | undefined;
	}

	let {show = $bindable(false), onpick, filter, children, ...rest}: Props = $props();
</script>

{#if show}
	<Dialog {...rest}>
		<div class="pane p_md width_md mx_auto">
			{@render children?.()}
			<Model_Picker bind:show {onpick} {filter} />
		</div>
	</Dialog>
{/if}
