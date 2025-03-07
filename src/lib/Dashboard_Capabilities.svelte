<script lang="ts">
	import {DEV} from 'esm-env';

	import {GLYPH_CAPABILITY} from '$lib/glyphs.js';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import Breadcrumb from '@ryanatkn/fuz/Breadcrumb.svelte';
	import Library_Footer from '@ryanatkn/fuz/Library_Footer.svelte';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import Control_Panel from '$lib/Control_Panel.svelte';

	import {pkg_context} from '$routes/pkg.js';

	const pkg = pkg_context.get();

	// TODO display capabilities (like what APIs are available, including remote server (off when deployed statically), local pglite (could be disconnected, websockets?))
	// TODO display database info/explorer
</script>

<div class="p_lg">
	<header>
		<h1><Glyph_Icon icon={GLYPH_CAPABILITY} /> system capabilities</h1>
	</header>
	<section class="width_md">
		<h2>todo</h2>
		<aside>
			⚠️ This is unfinished. It will show the capabilities available to the system. Zzz can run in
			many contexts, and users are empowered by the capabilities available in each.
		</aside>
		<ul>
			<li>local Ollama API</li>
			<li>utility models (like the first one for `namerbot`)</li>
			<li>Node server</li>
			<ul class="mb_0">
				<li>websocket connection</li>
			</ul>
			<li>AI providers (API keys)</li>
			<li>pg db (Postgres, pglite, or some other compatible database)</li>
			<li>ephemerally connected devices - mic, webcam, midi, etc</li>
		</ul>
	</section>
	<section>
		<Control_Panel />
	</section>
	<section class="width_sm">
		<p>
			DEV mode: {DEV.toString()}
		</p>
	</section>
	<section class="mb_xl7 flex">
		<Library_Footer {pkg}>
			<div class="mb_xl5">
				<Breadcrumb><Svg data={zzz_logo} size="var(--icon_size_sm)" /></Breadcrumb>
			</div>
		</Library_Footer>
	</section>
</div>
