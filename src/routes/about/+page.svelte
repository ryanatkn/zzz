<script lang="ts">
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import Package_Detail from '@ryanatkn/fuz/Package_Detail.svelte';
	import Community_Links_Panel from '@ryanatkn/fuz/Community_Links_Panel.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';

	import {pkg_context} from '$routes/pkg.js';
	import External_Link from '$lib/External_Link.svelte';
	import Footer from '$routes/Footer.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const pkg = pkg_context.get();
	const zzz = zzz_context.get();

	// TODO rewrite prose
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
			Zzz, pronounced "zees" like bees, is a webtool focused on user power and experimentation. The
			idea is to make a digital tool that adapts to your needs on the fly while remaining fully
			open, aligned, and in your control.
		</p>
		<!-- 
		<p>
			This is a pre-alpha, but it can do some neat things - mostly these require the local server
			<a href="{base}/capabilities">capability</a>, so if you're reading this on the static web,
			you'll have a much-diminished experience, some of which I just need to spend time to improve),
			and it points to what I think is an interesting and desirable future. This first release took
			about 2 months of development and I have a lot of things planned - it feels very early but
			knowing myself I needed to ship asap! I've thought about and prototyped related ideas for more
			than 12 years, and I think this iteration is sticking.
		</p>
		<p>
			Asking the right questions for the complex problems we face in technology is hard. Trying to
			boil it down,
		</p>
		<blockquote>"What can software do for us, and who controls it?"</blockquote>
		<p>More specifically,</p>
		<blockquote>
			"How can composable computing environments transform user agency in the age of AI?"
		</blockquote>
		<p>but with less true-believer energy and more detail:</p>
		<blockquote>
			"What becomes possible when web users move from exploitative service-controlled spaces to
			user-controlled environments that are open, extensible, and well-designed, with unrestricted
			access to local and remote capabilities?"
		</blockquote>
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
				> - Zzz gains huge capabilities when it has access to a server, local or remote, but it also
				works in static apps
			</li>
			<li>
				web metaframeworks – Zzz extends <External_Link href="https://svelte.dev/"
					>SvelteKit</External_Link
				> and <External_Link href="https://vite.dev/">Vite</External_Link> without wrapping them, enabling
				devs to use Zzz as a library/framework/tool without workflow intrusion
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
				my current thinking is that Zzz's ideal form on the desktop is a forward evolution of the
				browser, basically wrapping today's familiar browser experience with optional features like
				the above, and then an endless list of things like website builders, web IDEs, local code
				editors, wikis and other knowledge management systems, social media apps, cloud office
				suites, content creation apps, and so on
			</li>
		</ul>
		<p>
			Most features are optional through plugins, so the core experience stays efficient and
			economical for what it offers.
		</p>
		<aside>
			Does this scope look silly? Though ambitious, I think we're going to see *many* software
			projects aim for a scope like Zzz in large part because AI can automatically generate
			sophisticated problem-specific UIs and software from natural language instructions, and it
			simultaneously lowers the barrier to entry to create your own software, especially when there
			are high quality examples available. IMO for the web, the browser must become a
			holistically-designed data management environment to stay relevant.
		</aside>
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
		</p> -->
	</section>
	<hr />
	<section>
		<h2 class="mb_lg">into the future</h2>
		<p class="mb_md">
			This project has a huge scope and it's early in development. What you're seeing is a small
			fraction of the idea - especially if you're viewing this on the website not natively via Node
			- so here's a button for previewing some of what's planned:
		</p>
		<button
			type="button"
			class:color_h={zzz.futuremode}
			onclick={() => {
				zzz.futuremode = !zzz.futuremode;
			}}
		>
			<Svg
				data={zzz_logo}
				size="var(--icon_size_sm)"
				fill={zzz.futuremode ? 'var(--color_h_5)' : 'var(--text_color)'}
				attrs={{
					class: 'mr_md' + (zzz.futuremode ? ' flip_x' : ''),
					style: 'transition: transform 200ms ease',
				}}
			/>
			<span
				><span class="inline_block text_align_right" style:width="6ch"
					>{zzz.futuremode ? 'disable' : 'enable'}</span
				>
				futuremode</span
			>
			<Svg
				data={zzz_logo}
				size="var(--icon_size_sm)"
				fill={zzz.futuremode ? 'var(--color_h_5)' : 'var(--text_color)'}
				attrs={{
					class: 'ml_md' + (zzz.futuremode ? '' : ' flip_x'),
					style: 'transition: transform 200ms ease',
				}}
			/>
		</button>
	</section>
	<hr />
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
