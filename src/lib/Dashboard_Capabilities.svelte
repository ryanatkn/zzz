<script lang="ts">
	import {GLYPH_CAPABILITY} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import Footer from '$lib/Footer.svelte';
	import Capabilities_View from '$lib/Capabilities_View.svelte';
</script>

<div class="p_lg">
	<header>
		<h1><Glyph glyph={GLYPH_CAPABILITY} /> system capabilities</h1>
	</header>
	<section class="width_md">
		<p>
			This page lets you view and control the app's capabilities, powers that determine what you can
			do with it.
		</p>
		<p>
			Zzz's goal is to connect your intent to the world through machines, so it runs in many
			contexts, and you can do whatever you wish with whatever capabilities are on hand.
		</p>
	</section>
	<section>
		<Capabilities_View />
	</section>
	<section class="mb_xl7 display_flex justify_content_center">
		<Footer />
	</section>
</div>
