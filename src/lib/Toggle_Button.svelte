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
	}

	const {active, active_content, inactive_content, ontoggle, attrs}: Props = $props();
</script>

<button type="button" class="plain icon_button" {...attrs} onclick={() => ontoggle(!active)}>
	<span class="relative">
		<span style:visibility="hidden" class="inline_flex flex_column">
			<span>
				{#if typeof active_content === 'string'}{active_content}{:else}{@render active_content()}{/if}
			</span>
			<span>
				{#if typeof inactive_content === 'string'}{inactive_content}{:else}{@render inactive_content()}{/if}
			</span>
		</span>
		<span class="absolute inline_flex align_items_center justify_content_center" style:inset="0">
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
