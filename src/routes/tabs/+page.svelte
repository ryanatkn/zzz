<script lang="ts">
	import {GLYPH_TAB} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import {base} from '$app/paths';
</script>

<div class="p_lg">
	<h1><Glyph icon={GLYPH_TAB} /> tabs</h1>

	<section class="width_md">
		<p>
			When installed as a native app, Zzz extends the web browser using the form factor you already
			know well - imagine your current browser, and then add a sidebar on the left like the one on
			this page.
		</p>
		<p>
			This simple change reimagines the web's UX - instead of being stuck inside tabs and apps,
			users can compose pages in a larger system that's open and extensible by design. I believe the
			optimal architecture both respects individual rights while unlocking capabilities like
			<a href="{base}/sites">website creation</a> and adaptive UI. And we can build it today, it's not
			that hard with the web's amazing tools.
		</p>
		<p>
			Thinking more abstractly, web browsers are already embedded in operating systems, so Zzz
			shares perspectives with operating system desktop environments like Windows, OSX, and the many
			Linux distros, but Zzz merges everything into the application runtime, unifying code and data
			and namespaces across deployment targets, leveraging the web and universal JS to their logical
			conclusion, hopefully so capable that you forget about your OS most of the time, and ideally
			lose track of Zzz even being a thing.
		</p>
		<p>More <a href="{base}/about">about</a> Zzz.</p>
	</section>
</div>
