<script module lang="ts">
	let browser: Browser;
</script>

<script lang="ts">
	import {base} from '$app/paths';

	import {GLYPH_TAB} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import {Browser} from '$routes/tabs/browser.svelte.js';
	import {sample_tabs} from '$routes/tabs/sample_tabs.js';
	import Browser_View from '$routes/tabs/Browser_View.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import External_Link from '$lib/External_Link.svelte';

	const zzz = zzz_context.get();

	// Initialize browser with the sample tabs and Zzz instance
	// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
	browser ??= new Browser({
		zzz,
		json: {tabs: sample_tabs},
	});
</script>

{#if browser.browserified}
	<Browser_View {browser}>
		{@render content()}
	</Browser_View>
{:else}
	<div class="p_lg">
		{@render content()}
	</div>
{/if}

{#snippet content()}
	<h1><Glyph text={GLYPH_TAB} /> tabs</h1>

	<section class="width_md">
		{#if browser.browserified}
			<aside>
				⚠️⚠️ This is just a demo of planned functionality, nothing works like it should. Zzz will
				need a native installation to function like a real browser. The initial version will use
				Chromium via Electron, and long term, a user-friendly design would allow choosing your
				engine among Chromium, Firefox, Safari, Ladybird, etc.
			</aside>
		{/if}
		<p>
			When installed as a native app instead of running in a browser tab, Zzz extends the web
			browser using the form factor you already know well - imagine your current browser, and then
			add a sidebar on the left like the one on this page, then <button
				type="button"
				onclick={() => (browser.browserified = !browser.browserified)}
				class:color_i={!browser.browserified}
				class:color_h={browser.browserified}
				class="inline compact">{browser.browserified ? 'un' : ''}browserify!</button
			>
		</p>
		<p>
			And users don't have to buy in, either - the basic browser UX is unchanged. Press <code
				>[backtick `]</code
			>
			to
			<button
				type="button"
				class="inline compact color_d"
				onclick={() => {
					zzz.ui.toggle_sidebar();
					if (!browser.browserified) {
						browser.browserified = true;
					}
				}}>pretend it's all a dream</button
			>.
		</p>
		<p>
			This simple change recontextualizes the web's UX - instead of the browser being its own silo,
			users can compose tabs in a larger system that's open and extensible by design.
		</p>
		<p>
			As a simple example, picture adding arbitrary metadata like tags to both your browser tabs and
			files, both local and in the cloud, and then summoning UI that leverages that data for your
			specific needs in whatever context—without any technical knowledge, third parties, or
			unnecessary friction. The best usecases are still unknown because today's browsers don't let
			us experiment.
		</p>
		<p>
			I believe the optimal architecture—<External_Link
				href="https://www.inkandswitch.com/local-first/">local-first</External_Link
			>, <External_Link href="https://www.inkandswitch.com/malleable-software/"
				>malleable</External_Link
			>, client-sovereign—both respects individual rights and unlocks the full capabilities of web
			tech, including
			<a href="{base}/projects">website creation</a> and adaptive UI. And we can build it today, the
			web's tools are ready.
		</p>
		<p>More <a href="{base}/about">about</a> Zzz.</p>
	</section>
{/snippet}
