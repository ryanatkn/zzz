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
			This page lets you view and configure your system's capabilities. These constrain what Zzz can
			do - some tools and experiences depend on specific capabilities to function.
		</p>
		<p>
			For example, running AI models locally can be done through various strategies which all
			provide the capabilty of "chat with an AI" i.e. "get completions from local models", which is
			a subset of "get completions from models". (this is still a work in progress)
		</p>
		<p>
			Zzz's goal is to transparently connect your intent to the world through your machines, so it
			runs in many contexts and you can do whatever you wish with what's available.
		</p>
	</section>
	<section>
		<Capabilities_View />
	</section>
	<section class="mb_xl7 display_flex justify_content_center">
		<Footer />
	</section>
</div>
