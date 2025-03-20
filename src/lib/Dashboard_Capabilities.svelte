<script lang="ts">
	import {GLYPH_CAPABILITY} from '$lib/glyphs.js';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import Footer from '$routes/Footer.svelte';
	import Capabilities_View from '$lib/Capabilities_View.svelte';

	// TODO display capabilities (like what APIs are available, including remote server (off when deployed statically), local pglite (could be disconnected, websockets?))
	// TODO display database info/explorer

	// TODO BLOCK use native popover with viewport-relative positioning
</script>

<div class="p_lg">
	<header>
		<h1><Glyph_Icon icon={GLYPH_CAPABILITY} /> system capabilities</h1>
	</header>
	<section class="width_md">
		<p>
			This page lets you view and control your system's current capabilities. These constrain what
			the rest of the application can do - Zzz provides many different UIs, and some UIs depend on
			specific capabilities to function. For example, running models locally can be done through
			various strategies which all provide the capabilty of "get completions from local models",
			which is a subset of "get completions from models", two related capabilities.
		</p>
		<p>
			Zzz's goal is to transparently connect your intent to your machines, so it runs in many
			contexts and you can do whatever you wish with the available capabilities.
		</p>
	</section>
	<section>
		<Capabilities_View />
	</section>
	<section class="mb_xl7 flex justify_content_center">
		<Footer />
	</section>
</div>
