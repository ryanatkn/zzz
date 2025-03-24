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
			fly while remaining fully open, aligned, and in your control.
		</p>
		<p>
			This is a pre-alpha, but it can do some neat things and points to what I think is an
			interesting future. This first release took about 2 months of development and I have a lot of
			things planned - it feels very early to me but I know myself and needed to ship asap! The idea
			is something I've thought about and prototyped for more than 12 years, and I think this
			iteration is sticking.
		</p>
		<p>Zzz is designed to be extensible to include features from many kinds of software:</p>
		<ul>
			<li>
				AI UIs like <External_Link href="https://github.com/Mintplex-Labs/anything-llm"
					>AnythingLLM</External_Link
				>, <External_Link href="https://github.com/open-webui/open-webui">Open WebUI</External_Link
				>, and <External_Link href="https://github.com/oobabooga/text-generation-webui"
					>Text generation web UI</External_Link
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
				> and <External_Link href="https://vite.dev/">Vite</External_Link> without wrapping them, giving
				devs significant freedom to use Zzz as a library/framework/tool without changing workflows
			</li>
			<li>
				<External_Link href="https://wikipedia.org/wiki/Content_management_system"
					>content management systems</External_Link
				>, headless and traditional - <External_Link
					href="https://wikipedia.org/wiki/List_of_content_management_systems"
					>Wikipedia list of CMSes</External_Link
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
			<li>content creation apps</li>
			<li>while we're at it, browsers and OS desktop environments, letting js shoot its shot</li>
		</ul>
		<p>
			Most features are optional through plugins, so the core experience stays efficient and
			economical for what it offers.
		</p>
		<p>Integrations: (everything's a work in progress, but some basics work)</p>
		<ul>
			<li>
				<External_Link href="https://github.com/ollama/ollama">Ollama</External_Link> (runs AI models
				locally, probably will swap for <External_Link href="https://github.com/ggml-org/llama.cpp"
					>llama.cpp</External_Link
				> which Ollama wraps)
			</li>
			<li>
				<External_Link href="https://github.com/openai/openai-node">ChatGPT</External_Link>,
				<External_Link href="https://github.com/anthropics/anthropic-sdk-typescript"
					>Claude</External_Link
				>, and <External_Link href="https://github.com/google-gemini/generative-ai-js"
					>Gemini</External_Link
				> (requires API keys)
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
						> to make the UX nice with persisted data
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
					<li>the unplanned-but-maybe? list is endless, pls feedback/requests/assistance</li>
				</ul>
			</li>
		</ul>
		<p>Some details about how I am thinking about Zzz as an open source project:</p>
		<ul>
			<li>Zzz is a noncommercial project and its only official domain is zzz.software</li>
			<li>
				it's permissively licensed open source and forking is encouraged (for less investment you
				can use it as a TypeScript/Svelte library (currently just npm))
			</li>
			<li>
				the Zzz name is owned by the community, just don't falsely represent yourself as the
				official Zzz project or zzz.software
			</li>
			<li>
				I'm looking for <a href="https://www.ryanatkn.com/funding">funding</a> to make my continued full-time
				work on Zzz sustainable
			</li>
		</ul>
		<p>
			Zzz is just one implementation of an increasingly common idea that leverages web tech with
			local-first software and powerful open clients, and it has quirks personal to its author that
			I'm generally open to smoothing out. Your input is appreciated to keep things on track and
			fun—see the
			<External_Link href="https://github.com/ryanatkn/zzz/issues">issues</External_Link>
			and
			<External_Link href="https://github.com/ryanatkn/zzz/discussions">discussions</External_Link>
			and find me on
			<External_Link href="https://bsky.app/profile/ryanatkn.com">Bluesky</External_Link>.
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
