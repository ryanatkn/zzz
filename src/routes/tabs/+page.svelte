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
		<p>
			When installed as a native app, Zzz extends the web browser using the form factor you already
			know well - imagine your current browser, and then add a sidebar on the left like the one on
			this page, then <button
				type="button"
				onclick={() => (browserified = !browserified)}
				class="inline compact color_i">browserify!</button
			>
		</p>
		<p>
			This simple change recontextualizes the web's UX - instead of being stuck inside tabs and
			apps, users can compose tabs in a larger system that's open and extensible by design.
		</p>
		<p>
			As a simple example, picture a "social media dashboard" that an AI can create in a few seconds
			from a few words. The UI puts two or more feeds from different social sites/apps side-by-side,
			where posting to all takes a single click, and no 3rd party service is needed. The best
			usecases are unknown, but today's browsers don't let us experiment.
		</p>
		<aside>
			<p>And users don't have to buy in, either - the basic browser UX is unchanged.</p>
			<p>Just press <code>[backtick `]</code> to pretend it's all a dream.</p>
		</aside>
		<p>
			I believe the optimal architecture - local-first, malleable, client-sovereign - both respects
			individual rights while unlocking the full capabilities of web tech, including
			<a href="{base}/sites">website creation</a> and adaptive UI. And we can build it today, it's not
			that hard with the web's amazing tools.
		</p>
		<p>More <a href="{base}/about">about</a> Zzz.</p>
	</section>
	<section class="width_md">
		<aside>
			Thinking more abstractly,<br /> web browsers are already embedded in operating systems,<br />
			so Zzz shares perspectives with operating system desktop environments—<br />—like Windows,
			OSX, and the many Linux distros,<br /> but Zzz sits way up high on a tower of web abstraction,<br
			/>
			gazing longingly at the metal below,<br /> and excitedly merges everything into a universal
			system runtime,<br />
			exposing capabilities to apps,<br /> unifying code and data and namespaces across deployment
			targets and runtime environments,<br /> leveraging the web and universal JS to their logical
			conclusions,<br /> hopefully so capable that you forget about your OS most of the time,<br /> and
			ideally lose track of Zzz even being a thing.
		</aside>
	</section>
{/snippet}
