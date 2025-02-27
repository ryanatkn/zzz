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
		<p>
			Zzz, pronounced "zees" like the sound of electricity, is a bot and web toolkit focused on user
			power and experimentation. The idea is to make a digital tool that adapts to your needs on the
			fly while remaining fully in your control and open source. It's currently pre-alpha and it
			will take some time for it to be featureful and reliable.
		</p>
		<p>
			Zzz is part of a growing ecosystem of open source client software that both provides a UI to
			AI, and also uses AI for self-enhancement at runtime. Today most people use AI through the
			proprietary clients of the major providers, and while that situation may continue, open
			clients like Zzz offer custom power that closed software can't match. Clients mediate and
			control our interactions with AI, so they're powerful and rather important, being able to
			gatekeep and shape the information we send and receive, and happily, they're becoming easier
			and cheaper to build and distribute.
		</p>
		<p>
			AI has opened new worlds of technology with vast new design spaces to explore, where anyone
			with ideas can participate. Zzz joins many other open software projects working towards
			individual and collective empowerment on the web. These projects operate publicly—sharing
			ideas, code, tools, protocols, and communities—as part of what I believe is a technological
			design convergence, spanning the web stack, on some new class of software prompted by the AI
			era.
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
				Planned:
				<ul>
					<li>pglite via Drizzle</li>
					<li>RSS/Atom/JSON Feed</li>
					<li>
						<External_Link href="https://activitypub.rocks/">ActivityPub</External_Link>
						and
						<External_Link href="https://atproto.com/">AT Protocol</External_Link>
					</li>
					<li>
						<External_Link href="https://modelcontextprotocol.io/"
							>Model Context Protocol</External_Link
						>
						(see its
						<External_Link href="https://github.com/modelcontextprotocol/typescript-sdk"
							>TypeScript lib</External_Link
						>
						)
					</li>
					<li>more planned, also I welcome feedback/requests/assistance</li>
				</ul>
			</li>
		</ul>
		<p>Zzz will include features from many kinds of software:</p>
		<ul>
			<li>AI frontends</li>
			<li>local-first apps</li>
			<li>web metaframeworks (Zzz extends and exposes SvelteKit)</li>
			<li>traditional content management systems</li>
			<li>headless content management systems</li>
			<li>static site generators</li>
			<li>local code editors</li>
			<li>web IDEs and integrated hosts</li>
			<li>cloud office suites</li>
			<li>wikis and knowledge management systems</li>
			<li>learning platforms</li>
			<li>
				people could technically make integrations with email and code forges, but I'm not going
				there in my head yet
			</li>
		</ul>
		<p>
			Most features are optional through plugins, so the core experience stays minimal and
			efficient.
		</p>
		<p>
			Zzz is just one implementation with quirks personal to its author, and it will evolve
			chaotically alongside its cohort of AI-informed web frontends. I'd love to get input of all
			kinds - for now see the
			<External_Link href="https://github.com/ryanatkn/zzz/issues">issues</External_Link>
			and
			<External_Link href="https://github.com/ryanatkn/zzz/discussions">discussions</External_Link>,
			or find me on
			<External_Link href="https://bsky.app/profile/ryanatkn.com">Bluesky</External_Link>.
		</p>
		<p class="mt_xl5">
			⚠️ This is an early pre-release, see the
			<External_Link href="https://github.com/ryanatkn/zzz">repo</External_Link>
			and
			<External_Link href="https://github.com/ryanatkn/zzz/discussions">discussions</External_Link>.
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
