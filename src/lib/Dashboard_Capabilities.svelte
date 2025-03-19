<script lang="ts">
	import {DEV} from 'esm-env';
	import {base} from '$app/paths';
	import Breadcrumb from '@ryanatkn/fuz/Breadcrumb.svelte';
	import Library_Footer from '@ryanatkn/fuz/Library_Footer.svelte';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';

	import {pkg_context} from '$routes/pkg.js';
	import {GLYPH_CAPABILITY} from '$lib/glyphs.js';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import Control_Panel from '$lib/Control_Panel.svelte';

	const pkg = pkg_context.get();

	// TODO display capabilities (like what APIs are available, including remote server (off when deployed statically), local pglite (could be disconnected, websockets?))
	// TODO display database info/explorer

	// TODO BLOCK Ollama capability

	// TODO BLOCK use native popover with viewport-relative positioning
</script>

<div class="p_lg">
	<header>
		<h1><Glyph_Icon icon={GLYPH_CAPABILITY} /> system capabilities</h1>
	</header>
	<section class="width_md">
		<aside>
			<p>⚠️ This is unfinished and needs more conceptual development.</p>
			<p>
				This page lets you view and control your system's current capabilities. These constrain what
				the rest of the application can do - Zzz provides many different UIs, and some UIs depend on
				specific capabilities to function. For example, running models locally can be done through
				various strategies which all provide the capabilty of "get completions from local models",
				which is a subset of "get completions from models", two related capabilities.
			</p>
			<p>
				Zzz's goal is to transparently connect your intent to your machines, so it runs in many
				contexts and users can do whatever they wish with the available capabilities.
			</p>
		</aside>
		<h2>todo</h2>
		<ul>
			<li>local Ollama API</li>
			<li>utility models (like the first one for `namerbot`)</li>
			<li>
				Node server - I think a component on this page under "server" below should call an http ping
				request if there's no socket connection
			</li>
			<li>AI providers (API keys)</li>
			<li>pg db (Postgres, pglite, or some other compatible database)</li>
			<li>ephemerally connected devices - mic, webcam, midi, etc</li>
		</ul>
	</section>
	<section>
		<Control_Panel />
	</section>
	<section class="width_sm">
		<h2>system</h2>
		<div>
			<p class="font_mono">{pkg.name}@{pkg.package_json.version}</p>
			<p class="font_mono">
				DEV: {DEV + ''}
			</p>
			<p><a href="{base}/about">/about</a></p>
		</div>
	</section>
	<section class="mb_xl7 flex justify_content_center">
		<Library_Footer {pkg}>
			<div class="mb_xl5">
				<Breadcrumb><Svg data={zzz_logo} size="var(--icon_size_sm)" /></Breadcrumb>
			</div>
		</Library_Footer>
	</section>
</div>
