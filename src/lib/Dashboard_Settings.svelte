<script lang="ts">
	import {GLYPH_SETTINGS} from '$lib/glyphs.js';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import Settings from '$lib/Settings.svelte';

	import Footer from '$routes/Footer.svelte';

	// TODO display capabilities (like what APIs are available, including remote server (off when deployed statically), local pglite (could be disconnected, websockets?))
	// TODO display database info/explorer
</script>

<div class="p_lg">
	<header>
		<h1><Glyph_Icon icon={GLYPH_SETTINGS} /> system settings</h1>
	</header>
	<section class="width_sm">
		<Settings />
	</section>
	<section class="mb_xl7 flex justify_content_center">
		<Footer />
	</section>
</div>
