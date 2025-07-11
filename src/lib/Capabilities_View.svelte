<script lang="ts">
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import Svg from '@ryanatkn/fuz/Svg.svelte';

	import Capability_Websocket from '$lib/Capability_Websocket.svelte';
	import Capability_Filesystem from '$lib/Capability_Filesystem.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import Provider_Logo from '$lib/Provider_Logo.svelte';
	import {GLYPH_CONNECT, GLYPH_DIRECTORY, GLYPH_BACKEND} from '$lib/glyphs.js';
	import Capability_Ollama from '$lib/Capability_Ollama.svelte';
	import Capability_Backend from '$lib/Capability_Backend.svelte';
	import Capability_System from '$lib/Capability_System.svelte';

	// TODO add Capability_Chatgpt|Gemini|Claude (or the company equivalents)

	// TODO add ping button that forces websocket transport
</script>

<div class="width_md">
	<section>
		<section class="mb_xl12">
			<h2><Glyph glyph={GLYPH_BACKEND} /> backend</h2>
			<Capability_Backend />
		</section>
		<section class="mb_xl12">
			<h2><Glyph glyph={GLYPH_DIRECTORY} /> backend filesystem</h2>
			<Capability_Filesystem />
		</section>
		<section class="mb_xl12">
			<h2><Glyph glyph={GLYPH_CONNECT} /> backend websocket</h2>
			<p>
				Websockets are an optional transport that's preferred by default. Zzz currently relies on
				websockets for pushed updates like filesystem changes - SSE support as an alternative will
				be added in the future. (will it work for all usecases?)
			</p>
			<Capability_Websocket />
		</section>
		<section class="mb_xl12">
			<h2><Provider_Logo name="ollama" /> Ollama</h2>
			<Capability_Ollama />
		</section>
		<section class="mb_xl12">
			<h2>
				<Svg data={zzz_logo} size="var(--icon_size_sm)" fill="var(--text_color)" inline /> system
			</h2>
			<Capability_System />
		</section>
	</section>
</div>
