<script lang="ts">
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import Svg from '@ryanatkn/fuz/Svg.svelte';

	import Capability_Websocket from '$lib/Capability_Websocket.svelte';
	import Capability_Filesystem from '$lib/Capability_Filesystem.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import Provider_Logo from '$lib/Provider_Logo.svelte';
	import {GLYPH_CONNECT, GLYPH_DIRECTORY, GLYPH_SERVER} from '$lib/glyphs.js';
	import Capability_Ollama from '$lib/Capability_Ollama.svelte';
	import Capability_Server from '$lib/Capability_Server.svelte';
	import Capability_System from '$lib/Capability_System.svelte';
</script>

<div class="width_md">
	<section>
		<section class="mb_xl12">
			<h2><Glyph glyph={GLYPH_SERVER} /> server</h2>
			<Capability_Server />
		</section>
		<section class="mb_xl12">
			<h2><Glyph glyph={GLYPH_DIRECTORY} /> server filesystem</h2>
			<Capability_Filesystem />
		</section>
		<section class="mb_xl12">
			<h2><Glyph glyph={GLYPH_CONNECT} /> server websocket</h2>
			<Capability_Websocket />
		</section>
		<section class="mb_xl12">
			<h2><Provider_Logo name="ollama" /> Ollama</h2>
			<Capability_Ollama />
		</section>
		<section class="mb_xl12">
			<h2>
				<Svg data={zzz_logo} size="var(--icon_font_size_sm)" fill="var(--text_color)" inline /> system
			</h2>
			<Capability_System />
		</section>
	</section>
</div>
