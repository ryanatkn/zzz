<script lang="ts">
	import Confirm_Button_Examples from '$lib/Confirm_Button_Examples.svelte';
	import Popover_Button_Examples from '$lib/Popover_Button_Examples.svelte';

	interface Props {
		show_variants?: boolean;
	}

	const {show_variants = true}: Props = $props();
</script>

<div class="mb_xl">
	<h2>Popover System Components</h2>

	<p>
		These examples showcase the flexible popover system components that can be used for various UI
		interactions.
	</p>

	<div class="mb_xl">
		<h3>Delete Button</h3>
		<p>A specialized button for delete/remove actions with confirmation.</p>
		<Confirm_Button_Examples {show_variants} />
	</div>

	<div class="mb_xl">
		<h3>Popover Button</h3>
		<p>A general-purpose popover system for tooltips, menus, dialogs and more.</p>
		<Popover_Button_Examples {show_variants} />
	</div>
</div>

<!-- Suggestion for future development -->
<div class="p_md bg_c_1 color_bg radius_md mb_xl">
	<h3 class="mt_0">Next Steps for Popover Components</h3>
	<ol>
		<li>
			<strong>Usage Documentation</strong> - Add more detailed usage documentation explaining when to
			use each component
		</li>
		<li>
			<strong>Specialized Variants</strong> - Consider adding more specialized variants like:
			<ul>
				<li>Tooltip - Simple hover tooltips with various styles</li>
				<li>Dropdown - Dropdown menus for navigation or option selection</li>
				<li>Dialog - Modal-like popovers for important interactions</li>
			</ul>
		</li>
		<li>
			<strong>Accessibility Enhancements</strong> - Add keyboard navigation and focus management for
			better accessibility
		</li>
		<li>
			<strong>Animation Options</strong> - Allow customization of transition types and durations
		</li>
		<li>
			<strong>Position Strategy</strong> - Add smart positioning that avoids viewport edges
		</li>
	</ol>
</div>
