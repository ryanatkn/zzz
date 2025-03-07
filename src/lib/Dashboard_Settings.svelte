<script lang="ts">
	import {GLYPH_SETTINGS} from '$lib/glyphs.js';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import Settings from '$lib/Settings.svelte';
	import Breadcrumb from '@ryanatkn/fuz/Breadcrumb.svelte';
	import Library_Footer from '@ryanatkn/fuz/Library_Footer.svelte';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';

	import {pkg_context} from '$routes/pkg.js';

	const pkg = pkg_context.get();

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
	<section class="mb_xl7 flex">
		<Library_Footer {pkg}>
			<div class="mb_xl5">
				<Breadcrumb><Svg data={zzz_logo} size="var(--icon_size_sm)" /></Breadcrumb>
			</div>
		</Library_Footer>
	</section>
</div>
