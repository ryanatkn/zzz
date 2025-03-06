<script lang="ts">
	import Library_Footer from '@ryanatkn/fuz/Library_Footer.svelte';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import Package_Detail from '@ryanatkn/fuz/Package_Detail.svelte';
	import Community_Links_Panel from '@ryanatkn/fuz/Community_Links_Panel.svelte';
	import Breadcrumb from '@ryanatkn/fuz/Breadcrumb.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';

	import {pkg_context} from '$routes/pkg.js';
	import External_Link from '$lib/External_Link.svelte';

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
			fly while remaining fully in your control and open source. It's currently pre-alpha and it
			will take some time for it to be featureful and reliable, but it can already do some neat
			things.
		</p>
		<p>
			Zzz is part of a growing ecosystem of open source client software that both provides a UI to
			AI, and also uses AI to enhance the UX and runtime capabilities. I expect that in the future,
			AI will create our UIs on demand, and I think a lot of existing software will evolve to become
			this kind of client that does whatever you need it to do. Today most people use AI through the
			proprietary clients of the major providers, and while that situation may continue, open
			clients like Zzz offer custom power that closed software can't access. A user of an open
			client may begin by comparing the outputs of two models, but the possibilities are an entire
			social universe unavailable to closed software.
		</p>
		<p>
			Clients mediate and control our interactions with AI, so they're powerful and rather
			important, being able to gatekeep and shape the information we send and receive. Trusting
			one's client is important for health. Fortunately, they're becoming easier and cheaper to
			build and distribute.
		</p>
		<p>
			AI has opened new worlds of technology with vast new spaces to explore where anyone with
			language can participate. Zzz joins many other open software projects working towards
			individual and collective empowerment on the web. These projects operate publicly—sharing
			ideas, code, tools, protocols, and communities—as part of what I believe is a technological
			design convergence on a new class of software prompted by LLMs. (by design convergence I mean
			the genre of web app/software, not everyone using Tailwind) This software genre spans the full
			stack, values openness and interoperability, and aims to integrate all the things in one UX
			with uncompromising control in users' hands.
		</p>
		<p>
			I think over time the most fit solutions will emerge, and clients (hopefully Zzz) will
			converge toward a smoother, more unified web-based AI-interfacing experience where consumers
			choose among open clients according to their taste.
		</p>
		<p>The main ideas of Zzz include: (I'm sure I'm missing some)</p>
		<ul>
			<li>optimize for user agency and power</li>
			<li>care about UX for both power users and novices</li>
			<li>open source, permissive license, noncommercial project</li>
			<li>
				local-first architecture with offline functionality, user-controlled data, client
				sovereignty, and optional cloud deployment (create websites!) and sync
			</li>
			<li>
				interoperable design using standard and popular protocols (see ahead), open APIs, the web
				and JS ecosystem, and common data formats
			</li>
			<li>
				designed for plugins, scripting, and deep extensibility, and has a dev library in TypeScript
				and Svelte
			</li>
			<li>
				composable building blocks that you can configure and combine based on the available
				capabilities, both manually and with AI, to create new experiences and tools that solve your
				unique problems, and share them with others
			</li>
			<li>
				adaptable interfaces that evolve with user needs through customization, context awareness,
				and AI assistance
			</li>
		</ul>
		<p>Integrations: (everything's a work in progress, but some basics work)</p>
		<ul>
			<li>
				<External_Link href="https://github.com/ollama/ollama">Ollama</External_Link>
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
					<li>more plans in my head, also I welcome feedback/requests/assistance</li>
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
				>, headless and traditional, see this <External_Link
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
			<li>cloud office suites</li>
			<li>website builders and web IDEs</li>
			<li>social media apps</li>
			<li>learning platforms</li>
			<li>local code editors (supplementing editors like VSCode, not replacing)</li>
			<li>
				people could technically make integrations with code forges and even email, but I'm not
				thinking that far ahead, but maybe Zzz will converge with Gmail
			</li>
		</ul>
		<p>
			Most features are optional through plugins, so the core experience stays minimal and
			efficient.
		</p>
		<p>
			Zzz is just one implementation of an increasingly common idea with quirks personal to its
			author, and I expect it to evolve chaotically alongside its cohort of AI-informed web
			software, with the goal of converging with the herd on the many specific choices that improve
			the ecosystem's interoperability. Your input is highly valued to keep things on track and
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
		<Library_Footer {pkg}>
			<div class="mb_xl5">
				<Breadcrumb><Svg data={zzz_logo} size="var(--icon_size_sm)" /></Breadcrumb>
			</div>
		</Library_Footer>
	</section>
</div>
