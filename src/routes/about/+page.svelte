<script lang="ts">
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import Package_Detail from '@ryanatkn/fuz/Package_Detail.svelte';
	import Community_Links_Panel from '@ryanatkn/fuz/Community_Links_Panel.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';

	import {pkg_context} from '$routes/pkg.js';
	import External_Link from '$lib/External_Link.svelte';
	import Footer from '$routes/Footer.svelte';

	const pkg = pkg_context.get();

	// TODO standardize
</script>

<div class="width_md p_lg">
	<section>
		<header style:--size="var(--size_xl)">
			<h1 class="row">
				<Svg
					data={zzz_logo}
					fill="var(--text_color)"
					size="var(--icon_size_sm)"
					attrs={{class: 'ml_xs mr_xl'}}
				/> about
			</h1>
		</header>
		<aside class="mt_xl5">
			⚠️ this is an early pre-release, see the
			<External_Link href="https://github.com/ryanatkn/zzz">repo</External_Link>
			and
			<External_Link href="https://github.com/ryanatkn/zzz/discussions">discussions</External_Link> 💤
		</aside>
		<p>
			Zzz, pronounced "zees" like the sound of electricity, is a bot and web toolkit focused on user
			power and experimentation. The idea is to make a digital tool that adapts to your needs on the
			fly while remaining fully open, aligned, and in your control. It's currently pre-alpha and it
			will take some time for it to be featureful and reliable, but it can already do some neat
			things.
		</p>
		<p>Integrations: (everything's a work in progress, but some basics work)</p>
		<ul>
			<li>
				<External_Link href="https://github.com/ollama/ollama">Ollama</External_Link> (to be swapped
				for <External_Link href="https://github.com/ggml-org/llama.cpp">llama.cpp</External_Link>)
			</li>
			<li>
				<External_Link href="https://github.com/openai/openai-node">ChatGPT</External_Link>
			</li>
			<li>
				<External_Link href="https://github.com/anthropics/anthropic-sdk-typescript"
					>Claude</External_Link
				>
			</li>
			<li>
				<External_Link href="https://github.com/google-gemini/generative-ai-js"
					>Gemini</External_Link
				>
			</li>
			<li>
				<External_Link href="https://hono.dev/">Hono</External_Link> as the web server with
				<External_Link href="https://svelte.dev/">SvelteKit</External_Link> and <External_Link
					href="https://vite.dev/">Vite</External_Link
				>
			</li>
			<li>
				Planned:
				<ul>
					<li>
						<External_Link href="https://github.com/electric-sql/pglite">pglite</External_Link> via
						<External_Link href="https://github.com/drizzle-team/drizzle-orm">Drizzle</External_Link
						>
					</li>
					<li>
						<External_Link href="https://wikipedia.org/wiki/RSS">RSS</External_Link> and <External_Link
							href="https://wikipedia.org/wiki/Atom_(web_standard)">Atom</External_Link
						> and <External_Link href="https://wikipedia.org/wiki/JSON_Feed"
							>JSON Feed</External_Link
						>
					</li>
					<li>
						<External_Link href="https://activitypub.rocks/">ActivityPub</External_Link>
						and
						<External_Link href="https://atproto.com/">AT Protocol</External_Link>
					</li>
					<li>
						<External_Link href="https://modelcontextprotocol.io/"
							>Model Context Protocol</External_Link
						>
						via its
						<External_Link href="https://github.com/modelcontextprotocol/typescript-sdk"
							>TypeScript lib</External_Link
						>
					</li>
					<li>pls feedback/requests/assistance</li>
				</ul>
			</li>
		</ul>
		<p>Zzz will include features from many kinds of software:</p>
		<ul>
			<li>
				AI frontends and fullstack apps like <External_Link
					href="https://github.com/Mintplex-Labs/anything-llm">AnythingLLM</External_Link
				>
				and <External_Link href="https://github.com/open-webui/open-webui">Open WebUI</External_Link
				>
			</li>
			<li>
				local-first apps – see <External_Link href="https://localfirstweb.dev/"
					>localfirstweb.dev</External_Link
				> and this
				<External_Link href="https://www.inkandswitch.com/local-first/"
					>Ink & Switch post</External_Link
				>
			</li>
			<li>
				web metaframeworks – Zzz extends <External_Link href="https://svelte.dev/"
					>SvelteKit</External_Link
				> and <External_Link href="https://vite.dev/">Vite</External_Link> without wrapping them
			</li>
			<li>
				<External_Link href="https://wikipedia.org/wiki/Content_management_system"
					>content management systems</External_Link
				> (CMS), headless and traditional, see this <External_Link
					href="https://wikipedia.org/wiki/List_of_content_management_systems"
					>list on Wikipedia</External_Link
				>
			</li>
			<li>
				<External_Link href="https://wikipedia.org/wiki/Static_site_generator"
					>static site generators</External_Link
				>
			</li>
			<li>
				<External_Link href="https://wikipedia.org/">wikis</External_Link> and other knowledge management
				systems
			</li>
			<li>website builders and web IDEs</li>
			<li>local code editors</li>
			<li>social media apps</li>
			<li>cloud office suites</li>
			<li>learning platforms</li>
			<li>content creation apps</li>
			<li>while we're at it, browsers and desktop environments</li>
		</ul>
		<p>
			Most features are optional through plugins, so the core experience stays efficient and
			economical for what it offers.
		</p>
		<p>
			Zzz is just one implementation of an increasingly common idea, and it has quirks personal to
			its author that I'm generally open to oatmealifying. Your input is highly valued to keep
			things on track and fun—see the
			<External_Link href="https://github.com/ryanatkn/zzz/issues">issues</External_Link>
			and
			<External_Link href="https://github.com/ryanatkn/zzz/discussions">discussions</External_Link>
			and find me on
			<External_Link href="https://bsky.app/profile/ryanatkn.com">Bluesky</External_Link>.
		</p>
		<p>
			I expect Zzz to evolve chaotically alongside its cohort of AI-informed web software, with the
			goal of ongoing convergence toward ecosystem-wide interoperability as protocols fall and rise,
			fundamentally anchored in powerful open clients and local-first software.
		</p>
	</section>
	<section>
		<div class="panel p_md width_md">
			<Package_Detail {pkg} />
		</div>
	</section>
	<Community_Links_Panel />
	<section class="mb_xl7">
		<Footer />
	</section>
</div>
