<script lang="ts">
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import Package_Detail from '@ryanatkn/fuz/Package_Detail.svelte';
	import Community_Links_Panel from '@ryanatkn/fuz/Community_Links_Panel.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';

	import {pkg_context} from '$lib/pkg.js';
	import External_Link from '$lib/External_Link.svelte';
	import Footer from '$lib/Footer.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';

	const pkg = pkg_context.get();
	const app = frontend_context.get();

	// TODO probably link to a blog post that's more approachable and less technical

	// TODO rewrite prose
</script>

<div class="width_md p_lg">
	<section>
		<header style:--font_size="var(--font_size_xl)">
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
			⚠️ This is an early pre-release, see the
			<External_Link href="https://github.com/ryanatkn/zzz">repo</External_Link>
			and
			<External_Link href="https://github.com/ryanatkn/zzz/discussions">discussions</External_Link> 💤
		</aside>
		<p>
			Zzz, pronounced "zees" like bees, is a software project focused on user power and
			experimentation. The idea is to make a fullstack software environment that adapts to your
			needs and intent while remaining fully open, aligned, and in your control. It's a flexible
			toolkit for consuming and creating content, developing web software, and crafting experiences
			with uncompromising UX and DX.
		</p>
		<p>
			In the technology landscape of 2025, where LLM-based AI is upending long held assumptions, and <External_Link
				href="https://wikipedia.org/wiki/Enshittification">enshittification</External_Link
			> is a widely-understood phenomenon among the very-online, Zzz asks:
		</p>
		<blockquote>
			"How can composable computing environments transform user agency in the age of AI?"
		</blockquote>
		<p>or with less true-believer energy and more detail:</p>
		<blockquote>
			"What becomes possible when web users move from exploitative service-controlled spaces to
			user-controlled environments that are open, extensible, and well-designed, with unrestricted
			access to local and remote capabilities?"
		</blockquote>
		<p>
			The software I imagine answering these questions is cross-platform so it runs everywhere, and
			for that we have the web with HTML, CSS, and JS. We want to solve problems once and have
			supported features work consistently whether you're on Windows, macOS, iOS, Android, Linux, or
			any other OS. For all its flaws and quirks, the web is the turf of our digital commons, and I
			believe it's capable of delivering a great UX when developers use it with care.
		</p>
		<p>
			When thinking about the web UX I want, my starting point is the user interface, because we're
			all users interfacing with machines. If this part isn't up to par, we're sunk before we sail.
			We want no compromises when it comes to control over our UI runtime, so this means we're using
			JS (thankfully, TypeScript makes this palatable). Zzz uses JS to glue software and machines
			together precisely the way you want, maximizing its utility on any device across the full
			stack. It can run locally on your machine using any of your available capabilities, or it can
			deploy anywhere JS runs to play whatever role you need.
		</p>
		<p>
			Zzz is based on many kinds of software, and it can be used to make any number of mashups of
			them:
		</p>
		<ul>
			<li>
				web browsers - planned with Chromium via Electron, ideally with swappable browser engines
			</li>
			<li>
				<External_Link href="https://wikipedia.org/wiki/Content_management_system"
					>content management systems</External_Link
				>, so you can make and manage websites, see this <External_Link
					href="https://wikipedia.org/wiki/List_of_content_management_systems">list</External_Link
				>
			</li>
			<li>
				AI UIs like <External_Link href="https://github.com/Mintplex-Labs/anything-llm"
					>AnythingLLM</External_Link
				>, <External_Link href="https://github.com/danny-avila/LibreChat">LibreChat</External_Link>,
				and <External_Link href="https://github.com/oobabooga/text-generation-webui"
					>Text generation web UI</External_Link
				>
			</li>
			<li>
				IDEs like <External_Link href="https://code.visualstudio.com/">VSCode</External_Link> for open-ended
				tooling and system access
			</li>
			<li>
				code libraries and web metaframeworks using TypeScript and Svelte - Zzz extends <External_Link
					href="https://svelte.dev/">SvelteKit</External_Link
				> and <External_Link href="https://vite.dev/">Vite</External_Link> without wrapping them, enabling
				devs to use Zzz as a library with existing workflows
			</li>
		</ul>
		<p>
			This scope may look far-fetched, and it is to me, but I'm just making tools that I want to use
			<em>now</em> on the best foundations I can assemble, with at least vague awareness of the endgame.
			I think the most successful version of Zzz is where it's used to build other systems, with different
			ideas and brands. Many of the initial systems have been designed with some thought towards this
			bigger picture, but it's too big an idea to be anywhere near complete, and I plan to continue building
			incrementally on a quality base with some experiements mixed in.
		</p>
		<p>
			Zzz must be easy to use and inclusive of people and devices, but it can't cater to everyone --
			however thanks to the magic of standards-based interoperability, Zzz works with all websites,
			like any other browser, and anything you make with Zzz works with other browsers and web
			technologies. It's just one way to use the web.
		</p>
		<p>
			I've been thinking about and prototyping related ideas for more than 13 years, and for the
			last 6 I've been working on my open source projects full-time, so there's a lot of thought and
			plans already formulated, but this iteration of Zzz was released after about 5 months from
			here I'm prioritizing user feedback and just shipping a
			continuously-improving-but-not-quite-usable proof-of-concept. I'm doing a lot of experimenting
			in places, so data and API stability aren't yet priorities. Some early (rough) integrations
			include:
		</p>
		<ul>
			<li>
				<External_Link href="https://github.com/ollama/ollama">Ollama</External_Link> runs AI models
				locally - more local LLM backends will be supported, this choice was an easy first step
			</li>
			<li>
				<External_Link href="https://github.com/openai/openai-node">ChatGPT</External_Link>,
				<External_Link href="https://github.com/anthropics/anthropic-sdk-typescript"
					>Claude</External_Link
				>, and <External_Link href="https://github.com/google-gemini/generative-ai-js"
					>Gemini</External_Link
				> - requires API keys
			</li>
			<li>
				<External_Link href="https://hono.dev/">Hono</External_Link> as the web server with
				<External_Link href="https://svelte.dev/">SvelteKit</External_Link> and <External_Link
					href="https://vite.dev/">Vite</External_Link
				>, plays a key coordinating role - Hono bases itself on web standards and supports all JS
				server runtimes
			</li>
			<li>
				Planned:
				<ul>
					<li>
						<!-- TODO @db -->
						<External_Link href="https://github.com/electric-sql/pglite">pglite</External_Link> via
						<External_Link href="https://github.com/drizzle-team/drizzle-orm">Drizzle</External_Link
						> and full <External_Link href="https://www.postgresql.org/">Postgres</External_Link> when
						desired, see <External_Link href="https://github.com/ryanatkn/zzz/issues/7"
							>issue #7</External_Link
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
						probably <External_Link href="https://modelcontextprotocol.io/"
							>Model Context Protocol</External_Link
						>
						and <External_Link href="https://github.com/google/A2A"
							>Agent2Agent (A2A) protocol</External_Link
						>
					</li>
					<li>
						I think it makes sense to prioritize a few high-utility integrations for manipulating
						media files, like <External_Link href="https://pandoc.org/">Pandoc</External_Link>,
						<External_Link href="https://ffmpeg.org/">ffmpeg</External_Link>, and <External_Link
							href="https://imagemagick.org/">ImageMagick</External_Link
						>
					</li>
					<li>more, please send feedback/requests/help</li>
				</ul>
			</li>
		</ul>
		<p>
			Zzz is one implementation of an increasingly common idea that combines web tech and AI with
			powerful open clients. Some related projects call themselves web UIs or even operating
			systems. I currently like word "environment" to describe the device+software UX, and "adaptive
			web environments" to get the bigger picture. Whatever the name, this class of app is something
			that I've been wanting for a long time, and I appear to be sticking with this iteration.
		</p>
		<p>
			If this sounds interesting and you would like to test out some broken pre-release software,
			input is appreciated to help make it work for you -- see the <External_Link
				href="https://github.com/ryanatkn/zzz">code</External_Link
			>,
			<External_Link href="https://github.com/ryanatkn/zzz/issues">issues</External_Link>, and
			<External_Link href="https://github.com/ryanatkn/zzz/discussions">discussions</External_Link>,
			and find me on my website or
			<External_Link href="https://bsky.app/profile/ryanatkn.com">Bluesky</External_Link>.
		</p>
	</section>
	<hr />
	<section>
		<h2 class="mb_lg">More details</h2>
		<ul>
			<li>Zzz is open source and permissively licensed, and forking is encouraged</li>
			<li>it's a noncommercial project and its only official domain is zzz.software</li>
			<li>
				the Zzz name/logos/IP are community property, just don't falsely represent the official Zzz
				project or zzz.software
			</li>
			<li>
				I'm looking for <a href="https://www.ryanatkn.com/funding">funding</a> to sustain my continued
				full-time work - if successful, I think Zzz will be stewarded by some kind of nonprofit
			</li>
		</ul>
	</section>
	<hr />
	<section>
		<h2 class="mb_lg">Into the future</h2>
		<p class="mb_md">
			This project has a huge scope and it's early in development. What you're seeing is a small
			fraction of the idea -- especially if you're viewing this on the website not natively via Node
			-- so here's a button for previewing some of what's planned:
		</p>
		<button
			type="button"
			class:color_h={app.futuremode}
			onclick={() => {
				app.futuremode = !app.futuremode;
			}}
		>
			<Svg
				data={zzz_logo}
				size="var(--icon_size_sm)"
				fill={app.futuremode ? 'var(--color_h_5)' : 'var(--text_color)'}
				attrs={{
					class: 'mr_md' + (app.futuremode ? ' flip_x' : ''),
					style: 'transition: transform 200ms ease',
				}}
			/>
			<span
				><span class="display_inline_block text_align_right" style:width="6ch"
					>{app.futuremode ? 'disable' : 'enable'}</span
				>
				futuremode</span
			>
			<Svg
				data={zzz_logo}
				size="var(--icon_size_sm)"
				fill={app.futuremode ? 'var(--color_h_5)' : 'var(--text_color)'}
				attrs={{
					class: 'ml_md' + (app.futuremode ? '' : ' flip_x'),
					style: 'transition: transform 200ms ease',
				}}
			/>
		</button>
	</section>
	<hr />
	<Community_Links_Panel />
	<section>
		<div class="panel p_md width_md">
			<Package_Detail {pkg} />
		</div>
	</section>
	<section class="mb_xl7">
		<Footer />
	</section>
</div>
