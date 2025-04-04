<script lang="ts">
	import {base} from '$app/paths';
	import {GLYPH_SITE} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
</script>

<div class="p_lg">
	<h1><Glyph icon={GLYPH_SITE} /> sites</h1>

	<section class="width_md">
		<p>
			When it's ready, Zzz will let you both <a href="{base}/tabs">browse websites</a> and also create
			them, so it's both a browser and editor for the read-write web, and it can be used as a desktop
			app to deploy and manage sites.
		</p>
		<p>
			For developers, Zzz is also an npm library for TypeScript, Svelte, SvelteKit, and Vite that
			can be used to make websites and servers with your current workflows.
		</p>
		<p>
			Zzz tries to give us the maximum of the web's capability on all of our devices with minimal
			dependencies and optional third parties. It's designed for extensibility and hackability, and
			a primary goal is to make managing websites incredibly boring and easy, because owning your
			web presence should be a cinch.
		</p>
		<p>More <a href="{base}/about">about</a> Zzz.</p>
	</section>
</div>
