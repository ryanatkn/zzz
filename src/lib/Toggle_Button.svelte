<script lang="ts">
	import type {Snippet} from 'svelte';
	import type {SvelteHTMLElements} from 'svelte/elements';

	interface Props {
		/**
		 * Current state of the toggle
		 */
		active: boolean;
		/**
		 * Content to display when toggle is active
		 */
		active_content: Snippet | string;
		/**
		 * Content to display when toggle is inactive
		 */
		inactive_content: Snippet | string;
		/**
		 * Callback when toggle state changes
		 */
		ontoggle: (active: boolean) => void;
		attrs?: SvelteHTMLElements['button'] | undefined;
		children?: Snippet | undefined;
	}

	const {active, active_content, inactive_content, ontoggle, attrs, children}: Props = $props();
</script>

<button type="button" class="plain icon_button" {...attrs} onclick={() => ontoggle(!active)}>
	{@render children?.()}
	<span class="position_relative">
		<span style:visibility="hidden" class="display_inline_flex flex_column h_0">
			<span>
				{#if typeof active_content === 'string'}{active_content}{:else}{@render active_content()}{/if}
			</span>
			<span>
				{#if typeof inactive_content === 'string'}{inactive_content}{:else}{@render inactive_content()}{/if}
			</span>
		</span>
		<span class="position_absolute display_inline_flex align_items_center" style:inset="0">
			{#if active}
				{#if typeof active_content === 'string'}{active_content}{:else}{@render active_content()}{/if}
			{:else if typeof inactive_content === 'string'}
				{inactive_content}
			{:else}
				{@render inactive_content()}
			{/if}
		</span>
	</span>
</button>
