<script lang="ts">
	import {base} from '$app/paths';

	import {GLYPH_TAB} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import {Browser} from '$routes/tabs/browser.svelte.js';
	import {sample_tabs} from '$routes/tabs/sample_tabs.js';
	import Browser_View from '$routes/tabs/Browser_View.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	let browserified = $state(false);

	const zzz = zzz_context.get();

	// Initialize browser with the sample tabs and Zzz instance
	const browser = new Browser({
		zzz,
		json: {tabs: sample_tabs},
	});
</script>

{#if browserified}
	<Browser_View {browser}>
		{@render content()}
	</Browser_View>
{:else}
	<div class="p_lg">
		{@render content()}
	</div>
{/if}

{#snippet content()}
	<h1><Glyph icon={GLYPH_TAB} /> tabs</h1>

	<section class="width_md">
		{#if browserified}
			<aside>
				⚠️⚠️⚠️ This is just a demo of planned functionality, nothing works like it should. Zzz will
				need a native installation to function like a real browser. The initial version will use
				Chromium via Electron, and long term, a user-friendly design would allow choosing your
				engine among Chromium, Firefox, Safari, Ladybird, etc.
			</aside>
		{/if}
		<p>
			When installed as a native app, Zzz extends the web browser using the form factor you already
			know well - imagine your current browser, and then add a sidebar on the left like the one on
			this page, then <button
				type="button"
				onclick={() => (browserified = !browserified)}
				class:color_i={!browserified}
				class:color_h={browserified}
				class="inline compact">{browserified ? 'un' : ''}browserify!</button
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
				disabled={browserified && !zzz.ui.show_sidebar}
				onclick={() => {
					if (zzz.ui.show_sidebar) {
						zzz.ui.toggle_sidebar();
					}
					if (!browserified) {
						browserified = true;
					}
				}}>pretend it's all a dream</button
			>.
		</p>
		<p>
			This simple change recontextualizes the web's UX - instead of being stuck inside tabs and
			apps, users can compose tabs in a larger system that's open and extensible by design.
		</p>
		<p>
			As a simple example, picture a "social media dashboard" that an AI can create in a few seconds
			from a few words. The UI puts two or more feeds from different social sites side-by-side,
			where posting to all takes a single click, and no 3rd party service is needed. The best
			usecases are unknown, but today's browsers don't let us experiment.
		</p>
		<p>
			I believe the optimal architecture - local-first, malleable, client-sovereign - both respects
			individual rights while unlocking the full capabilities of web tech, including
			<a href="{base}/sites">website creation</a> and adaptive UI. And we can build it today, the web's
			tools are ready.
		</p>
		<p>More <a href="{base}/about">about</a> Zzz.</p>
	</section>
{/snippet}
