<script lang="ts">
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import Package_Detail from '@ryanatkn/fuz/Package_Detail.svelte';
	import Community_Links_Panel from '@ryanatkn/fuz/Community_Links_Panel.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import {base} from '$app/paths';
	import Details from '@ryanatkn/fuz/Details.svelte';

	import {pkg_context} from '$lib/pkg.js';
	import External_Link from '$lib/External_Link.svelte';
	import Footer from '$lib/Footer.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';

	const pkg = pkg_context.get();
	const app = frontend_context.get();

	// TODO probably link to a blog post that's more approachable and less technical

	// TODO BLOCK review (also see the readme)
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
			experimentation. The idea is to make an integrated cross-platform environment that adapts to
			your needs and intent while remaining fully open, aligned, and in your control. It's flexible
			software for crafting experiences with maximal UX and streamlined DX.
		</p>
		<p>
			In the technology landscape of 2025, where LLM-based AI is upending long held assumptions, and <External_Link
				href="https://wikipedia.org/wiki/Enshittification">enshittification</External_Link
			> is a widely-understood phenomenon among the very-online, Zzz asks:
		</p>
		<blockquote>"How can we build the best software to support user agency with AI?"</blockquote>
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
				> -- this is the starting point so I can ship something I use at work (the
				<a href="{base}/prompts">prompt</a> builder is the most useful thing to me right now, followed
				by multi chats)
			</li>
			<li>
				IDEs like <External_Link href="https://code.visualstudio.com/">VSCode</External_Link> for open-ended
				tooling and system access
			</li>
			<li>
				web browsers, planned with Chromium via Electron, ideally with swappable browser engines
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
			now on the best foundations I can assemble. When designed for it, software has a way of
			accumulating into more than the sum of its parts. It will take time though, because I
			prioritize quality over velocity, and the project's resources are meager, having only my
			donated time right now -- of quality/velocity/cost, pick 2. A consequence is I can't really
			compete on features in the medium term, and working alone isn't the best. I think the most
			successful version of Zzz is where people use it to build products that people care about,
			where devs build whatever custom stuff on a community-supported stack, and Zzz fades into the
			background as just another part of the stack with a particular take.
		</p>
		<p>
			From a personal POV, Zzz is the primary user of my lower level software (Fuz/Moss/Gro/others),
			and it's the primary dependency of my planned products (websites/apps/etc, idk what I'm going
			to do exactly, I'm hestitant to involve myself with operating services -- I imagine Zzz
			Browser or something will be the planned Electron app). Many of the initial systems have been
			designed with some thought towards this bigger picture, trying to make Zzz reusable and
			reasonably tightly designed not sprawling, and I plan to continue building incrementally on a
			quality base with some lower-quality experiments and stubbed future features mixed in.
			(increasingly I'll experiment outside of the main codebase now that it's been announced)
		</p>
		<p>
			Zzz wants to be easy to use and inclusive of people and devices, but try as it might, it can't
			cater to every case for every person -- however, thanks to the magic of standards-based
			interoperability, as a browser Zzz works with all websites, and anything you make with Zzz
			works with other browsers and web technologies. It's one of infinite ways to use the web, and
			it's designed to help you level up your technical knowledge and abilities, if you're so
			inclined.
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
		</ul>
		<p>Planned integrations:</p>
		<ul>
			<li>
				<!-- TODO @db -->
				<External_Link href="https://github.com/electric-sql/pglite">pglite</External_Link>
				and full <External_Link href="https://www.postgresql.org/">Postgres</External_Link> when desired,
				using <External_Link href="https://github.com/porsager/postgres">Postgres.js</External_Link>
				and probably <External_Link href="https://github.com/drizzle-team/drizzle-orm"
					>Drizzle</External_Link
				>, see <External_Link href="https://github.com/ryanatkn/zzz/issues/7"
					>issue #7</External_Link
				>
			</li>
			<li>
				<External_Link href="https://modelcontextprotocol.io/">Model Context Protocol</External_Link
				>, maybe others like <External_Link href="https://github.com/google/A2A"
					>Agent2Agent (A2A) protocol</External_Link
				>
			</li>
			<li>
				<External_Link href="https://wikipedia.org/wiki/RSS">RSS</External_Link> and <External_Link
					href="https://wikipedia.org/wiki/Atom_(web_standard)">Atom</External_Link
				> and <External_Link href="https://wikipedia.org/wiki/JSON_Feed">JSON Feed</External_Link>
			</li>
			<li>
				<External_Link href="https://activitypub.rocks/">ActivityPub</External_Link>
				and
				<External_Link href="https://atproto.com/">AT Protocol</External_Link>
			</li>
			<li>
				I think it makes sense to prioritize a few high-utility integrations for manipulating media
				files, like <External_Link href="https://pandoc.org/">Pandoc</External_Link>,
				<External_Link href="https://ffmpeg.org/">ffmpeg</External_Link>, and <External_Link
					href="https://imagemagick.org/">ImageMagick</External_Link
				>
			</li>
			<li>
				more, input welcome
				<ul>
					<li>
						the system is being designed for extensibility, so your use cases are helpful for
						shaping it
					</li>
					<li>devs can extend Zzz to do anything but I want to provide a thoughtful base tool</li>
					<li>
						some decisions like Postgres lock us into a region of the possibility space in some
						respects -- you can always bring other databases but don't expect full integration, e.g.
						there is a serious mismatch with sqlite
					</li>
				</ul>
			</li>
		</ul>
		<p>
			Zzz is one implementation of an increasingly common idea that combines web tech and AI with
			powerful open clients. Some related projects call themselves web UIs, AI browsers, or even
			operating systems. I currently like word "environment" to describe the device+software UX, and
			"adaptive web environments" to get the bigger picture. Whatever the name or scope, I'll
			continue making modular software that can be used to build them.
		</p>
		<p>
			If this sounds interesting and you would like to test out some rickety pre-release software,
			feedback is appreciated to help make it work for you -- see the
			<External_Link href="https://github.com/ryanatkn/zzz/issues">issues</External_Link> and
			<External_Link href="https://github.com/ryanatkn/zzz/discussions">discussions</External_Link> or
			see my <External_Link href="https://www.ryanatkn.com/">website</External_Link> or
			<External_Link href="https://bsky.app/profile/ryanatkn.com">Bluesky</External_Link>.
		</p>
	</section>
	<hr />
	<section>
		<h2 class="mb_lg">More details</h2>
		<ul>
			<li>Zzz is open source and permissively licensed, and forking is encouraged</li>
			<li>it's a noncommercial project and its only official domain is zzz.software</li>
			<li>the Zzz name/logos/IP are community property, no rug to pull</li>
			<li>
				I'm looking for <a href="https://www.ryanatkn.com/funding">funding</a> to sustain my continued
				full-time work -- if successful, I think Zzz will be stewarded by some kind of nonprofit, and
				I'm open to employment that sponsors at least part-time work on Zzz and its dependencies (without
				changing the independence I have over my repos)
			</li>
		</ul>
	</section>
	<hr />
	<section>
		<h2 class="mb_lg">Peek futures</h2>
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
	<section>
		<h2 class="mb_lg">Security</h2>
		<aside>
			⚠️ I am not a security professional and Zzz is not audited -- treat it as possibly dangerous
			to run -- and any claims I make possibly misinformed
		</aside>
		<p>
			User agency requires reliable security, and I think the topic is worth a footnote in this
			otherwise high-level document. Zzz is an extensible system, and that means it carries
			important risks that must be managed.
		</p>
		<p>
			Zzz does its best to put the user in control, so one must have the ability to install what
			they wish, including obvious_malware. That leads me to UX design as a primary mechanism of
			influence to protect users, and design systems that maximize utility while simultaneously
			designing for safe usage.
		</p>
		<p>For now, I'm trying to keep things simple:</p>
		<ul>
			<li>
				The frontend <External_Link
					href="https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Content_Security_Policy"
					>CSP</External_Link
				> is fairly locked down, closing many vectors like unknown network connections. For details,
				see the CSP config in <External_Link
					href="https://github.com/ryanatkn/zzz/blob/main/svelte.config.js"
					>svelte.config.js</External_Link
				> and the <External_Link href="https://www.fuz.dev/docs/csp">Fuz CSP docs</External_Link>.
				We'll need to add config options, unlocking shenanigans good and bad, so we'll tread
				carefully. But at least we start from secure footing.
			</li>
			<li>
				Zzz's Node server can do things like:
				<ul>
					<li>
						read and write to the configured filesystem directory, <code>./</code>
						in production and <code>../</code> in development, securely scoped and does not follow symlinks
						-- this could potentially be disastrous, so don't give it a directory you treasure
					</li>
					<li>
						use your API keys for calls to Claude, ChatGPT, and Gemini -- $$ risk of lost credits
					</li>
					<li>
						call Ollama's API if available -- low risk but can devour your disk space and hog gpu
					</li>
				</ul>
			</li>
			<li>
				any modules you install via npm, or any code you add to the src directory, carry the normal
				(elevated) risks associated with development -- I practice good dependency <External_Link
					href="https://github.com/ryanatkn/fuz_template/issues/1">hygiene</External_Link
				>, and to give you an idea of my taste, postinstall scripts drive me nuts, like how dare you
				lol please _just_ the data
			</li>
			<li>
				In 2025, LLMs are known to be vulnerable to attacks like <External_Link
					href="https://wikipedia.org/wiki/Prompt_injection">prompt injection</External_Link
				>, where they are unable to reliably separate instructions intended by the prompter from
				adversarial instructions in the data. People are building digital horrors. Zzz will develop
				slowly here so you stay in control but yall, MCP is <External_Link
					href="https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/"
					attrs={{
						title:
							'Simon Willison’s Weblog: The lethal trifecta for AI agents: private data, untrusted content, and external communication',
					}}>wild</External_Link
				>
			</li>
			<li>I'm trying to be careful but I will make mistakes, help is always appreciated</li>
		</ul>
	</section>
	<hr />
	<Community_Links_Panel />
	<hr />
	<section>
		<Details>
			{#snippet summary()}package details{/snippet}
			<div class="panel p_md width_md">
				<Package_Detail {pkg} />
			</div>
		</Details>
	</section>
	<hr />
	<section class="mb_xl7">
		<Footer />
	</section>
</div>
