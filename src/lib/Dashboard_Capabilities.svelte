<script lang="ts">
	import {GLYPH_CAPABILITY} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import Footer from '$routes/Footer.svelte';
	import Capabilities_View from '$lib/Capabilities_View.svelte';
</script>

<div class="p_lg">
	<header>
		<h1><Glyph icon={GLYPH_CAPABILITY} /> system capabilities</h1>
	</header>
	<section class="width_md">
		<p>
			This page lets you view and control your system's capabilities. These constrain what the rest
			of the application can do - Zzz has many UIs and tools, and some depend on specific
			capabilities to function.
		</p>
		<p>
			For example, running models locally can be done through various strategies which all provide
			the capabilty of "get completions from local models", which is a subset of "get completions
			from models", two related capabilities. (this is still a work in progress)
		</p>
		<p>
			Zzz's goal is to transparently connect your intent to your machines, so it runs in many
			contexts and you can do whatever you wish with what's available.
		</p>
	</section>
	<section>
		<Capabilities_View />
	</section>
	<section class="mb_xl7 flex justify_content_center">
		<Footer />
	</section>
</div>
