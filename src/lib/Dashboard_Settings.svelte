<script lang="ts">
	import {GLYPH_SETTINGS} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import Settings from '$lib/Settings.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';

	import Footer from '$lib/Footer.svelte';

	const app = frontend_context.get();

	// TODO display capabilities (like what APIs are available, including remote server (off when deployed statically), local pglite (could be disconnected, websockets?))
	// TODO display database info/explorer
</script>

<div class="p_lg">
	<header>
		<h1><Glyph glyph={GLYPH_SETTINGS} /> system settings</h1>
	</header>
	<section class="width_sm">
		<Settings />

		<div class="mt_lg">
			<h3>ui</h3>
			<div class="my_md">
				<label class="row">
					<input type="checkbox" bind:checked={app.ui.show_sidebar} aria-label="show sidebar" />
					show sidebar <code class="ml_md">[backtick `]</code>
				</label>
			</div>
			<div class="my_md">
				<label class="row">
					<input
						type="checkbox"
						bind:checked={app.ui.show_main_dialog}
						aria-label="show main dialog"
					/>
					show main dialog
				</label>
			</div>
		</div>
	</section>
	<section class="mb_xl7 display_flex justify_content_center">
		<Footer />
	</section>
</div>
