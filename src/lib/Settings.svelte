<script lang="ts">
	import Color_Scheme_Input from '@ryanatkn/fuz/Color_Scheme_Input.svelte';
	import Theme_Input from '@ryanatkn/fuz/Theme_Input.svelte';

	import External_Link from '$lib/External_Link.svelte';
</script>

<h3>color scheme</h3>
<div class="width_sm mb_lg">
	<!-- TODO wanted to add `flex_1` to the buttons here, maybe add `menu_attrs` and `button_attrs`  -->
	<Color_Scheme_Input />
</div>
<p>
	Learn about <code>color-scheme</code> on <External_Link
		href="https://developer.mozilla.org/en-US/docs/Web/CSS/color-scheme">MDN</External_Link
	>.
</p>
<h3>theme</h3>
<aside>
	⚠️ Themes are a proof of concept, not ready for production. For technical docs see <External_Link
		href="https://moss.ryanatkn.com/docs/themes">Moss</External_Link
	>.
</aside>
<div class="width_sm box">
	<div class="width_xs">
		<Theme_Input />
	</div>
</div>
