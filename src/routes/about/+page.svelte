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
			Zzz, pronounced "zees" like bees, is a fullstack web toolkit with a focus on user power and
			experimentation. The idea is to make a cross-platform software environment that adapts to your
			needs and intent while remaining fully open, aligned, and in your control. It's a flexible
			toolkit for crafting experiences and tools with maximal UX and DX, like developing web
			software for creating and consuming content.
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
			supported features work consistently across operating systems and devices. For all its flaws
			and quirks, the web is the turf of our digital commons, and I believe it's capable of
			delivering a great UX when developers use it with care.
		</p>
		<p>
			When thinking about the web UX I want, my starting point is the user interface, because we're
			all users interfacing with machines. UX has primacy; the design serves it first. We want no
			compromises when it comes to control over our UI runtime, so this means we're using JS
			(thankfully, TypeScript). Zzz uses JS to glue software and machines together precisely the way
			you want, maximizing its utility on any device across the full stack. It can run locally on
			your machine using any of your available and granted capabilities, or it can deploy anywhere
			JS runs to play whatever role you need.
		</p>
		<p>
			Zzz is based on many kinds of software, borrowing features to provide end-users and devs an
			integrated and extensible system:
		</p>
		<ul>
			<li>
				LLM UIs like <External_Link href="https://github.com/Mintplex-Labs/anything-llm"
					>AnythingLLM</External_Link
				>, <External_Link href="https://github.com/danny-avila/LibreChat">LibreChat</External_Link>,
				and <External_Link href="https://github.com/oobabooga/text-generation-webui"
					>Text generation web UI</External_Link
				>, like LM Studio but FOSS and designed as a toolkit
			</li>
			<li>
				IDEs like <External_Link href="https://code.visualstudio.com/">VSCode</External_Link> for open-ended
				tooling and system access
			</li>
			<li>
				web browsers, planned with Chromium via Electron, ideally with swappable browser engines
				(webview-based toolkits like Tauri do not provide the web-integrated affordances I'm after,
				I think, but you can use Zzz with Tauri where it supports JS)
			</li>
			<li>
				<External_Link href="https://wikipedia.org/wiki/Content_management_system"
					>content management systems</External_Link
				>, so you can make and manage websites, see this <External_Link
					href="https://wikipedia.org/wiki/List_of_content_management_systems">list</External_Link
				>
			</li>
			<li>
				code libraries and web metaframeworks using TypeScript and <External_Link
					href="https://svelte.dev/">Svelte</External_Link
				> -- Zzz extends SvelteKit and <External_Link href="https://vite.dev/">Vite</External_Link> without
				wrapping them, enabling devs to use all or parts of Zzz as a library with existing workflows
			</li>
		</ul>
		<p>
			Putting it all together, we have a fullstack, fully capable, user-editable, and extensible
			system-and-toolkit that bridges dev workflows to end-user experiences, without prescribing
			changes to current behaviors and expectations.
		</p>
		<p>
			This scope may look far-fetched, and it is to me, but I'm just making tools that I want to use
			now on the best foundations I can assemble. I think the most successful version of Zzz is
			where it's used to build other systems, and it fades into the background as just another tool
			with a particular take on a part of the stack. From a personal POV, it's my flagship project
			and primary+priority user of my other software, and I plan to make various websites and tools
			with it. Many of the initial systems have been designed with some thought towards this bigger
			picture, and I plan to continue building incrementally on a quality base with some
			lower-quality experiments and stubbed future features mixed in.
		</p>
		<p>
			Zzz wants to be easy to use and inclusive of people and devices, but try as it might, it can't
			cater to every case for every person -- however, thanks to the magic of standards-based
			interoperability, Zzz works with all websites like you'd expect from a browser, and anything
			you make with Zzz works with other browsers and web technologies. It's one of infinite ways to
			use the web, and it's designed to help you level up your technical knowledge and abilities, if
			you're so inclined.
		</p>
		<p>Some early (rough) integrations include:</p>
		<ul>
			<li>
				<External_Link href="https://github.com/ollama/ollama">Ollama</External_Link> runs AI models
				locally -- more local LLM backends will be supported starting with <External_Link
					href="https://github.com/ggml-org/llama.cpp">llama.cpp</External_Link
				> which Ollama is based on -- Ollama prioritizes ease of use, so although you have to install
				it yourself separately, they make it about as easy as possible
			</li>
			<li>
				<External_Link href="https://github.com/openai/openai-node">ChatGPT</External_Link>,
				<External_Link href="https://github.com/anthropics/anthropic-sdk-typescript"
					>Claude</External_Link
				>, and <External_Link href="https://github.com/google-gemini/generative-ai-js"
					>Gemini</External_Link
				> -- requires you to bring your own API keys
			</li>
			<li>
				<External_Link href="https://hono.dev/">Hono</External_Link> as the web server with
				<External_Link href="https://svelte.dev/">SvelteKit</External_Link> and <External_Link
					href="https://vite.dev/">Vite</External_Link
				>, plays a key coordinating role -- Hono bases itself on web standards and supports all JS
				server runtimes
			</li>
			<li>
				planned:
				<ul>
					<li>
						<!-- TODO @db -->
						<External_Link href="https://github.com/electric-sql/pglite">pglite</External_Link>
						and full <External_Link href="https://www.postgresql.org/">Postgres</External_Link> when
						desired, using <External_Link href="https://github.com/drizzle-team/drizzle-orm"
							>Drizzle</External_Link
						> or maybe <External_Link href="https://github.com/porsager/postgres"
							>postgres</External_Link
						>, see <External_Link href="https://github.com/ryanatkn/zzz/issues/7"
							>issue #7</External_Link
						>
					</li>
					<li>
						<External_Link href="https://modelcontextprotocol.io/"
							>Model Context Protocol</External_Link
						>, maybe others like <External_Link href="https://github.com/google/A2A"
							>Agent2Agent (A2A) protocol</External_Link
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
						I think it makes sense to prioritize a few high-utility integrations for manipulating
						media files, like <External_Link href="https://pandoc.org/">Pandoc</External_Link>,
						<External_Link href="https://ffmpeg.org/">ffmpeg</External_Link>, and <External_Link
							href="https://imagemagick.org/">ImageMagick</External_Link
						>
					</li>
					<li>more, please send thoughts</li>
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
			feedback is appreciated to help make it work for you -- see the <External_Link
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
				full-time work - if successful, I think Zzz will be stewarded by some kind of nonprofit, and
				I'm open to employment that sponsors at least part-time work on Zzz and its dependencies (without
				changing the independence I have over my repos)
			</li>
		</ul>
	</section>
	<hr />
	<section>
		<h2 class="mb_lg">Peek into the future</h2>
		<p class="mb_md">
			This project has a big scope and it's early in development. What you're seeing is a small part
			of the idea -- especially if you're viewing this on the website not natively via Node -- so
			here's a button for previewing some of what's planned:
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
