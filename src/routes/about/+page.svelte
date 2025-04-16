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
			⚠️ This is an early pre-release, see the
			<External_Link href="https://github.com/ryanatkn/zzz">repo</External_Link>
			and
			<External_Link href="https://github.com/ryanatkn/zzz/discussions">discussions</External_Link> 💤
		</aside>
		<p>
			Zzz, pronounced "zees" like bees, is a software project focused on user power and
			experimentation. The idea is to make fullstack web tools that adapt to your needs on the fly
			while remaining fully open, aligned, and in your control.
		</p>
		<p>
			In the technology landscape of 2025, where LLMs are upending longheld assumptions and <External_Link
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
			for that we have the web with HTML, CSS, and JS. My conceptual starting point is the user
			interface. I'm a user, and I need to inferface with machines. Zzz leverages JS to glue
			software and machines together precisely the way you want, maximizing its utility on any
			device across the full stack. It can run locally on your machine using any of your available
			capabilities, or it can deploy anywhere that supports JS and play whatever role you need.
		</p>
		<p>Zzz is based on many kinds of software:</p>
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
				IDEs like <External_Link href="https://code.visualstudio.com/">VSCode</External_Link> for open-ended
				tooling and system access
			</li>
			<li>
				<External_Link href="https://wikipedia.org/wiki/Content_management_system"
					>content management systems</External_Link
				>, see this <External_Link
					href="https://wikipedia.org/wiki/List_of_content_management_systems">list</External_Link
				>
			</li>
			<li>
				web browsers - first with Chromium via Electron, hopefully with swappable browser engines
				one day
			</li>
			<li>
				web metaframeworks - Zzz extends <External_Link href="https://svelte.dev/"
					>SvelteKit</External_Link
				> and <External_Link href="https://vite.dev/">Vite</External_Link> without wrapping them, enabling
				devs to use Zzz as a library with existing workflows
			</li>
		</ul>
		<p>
			The scope may look far-fetched but I'm just building tools I want to use on the best
			foundations I can assemble. This is an early proof of concept that took about 3 months of
			fulltime work to build. (<External_Link href="https://github.com/ryanatkn/zzz/pull/6"
				>PR #6</External_Link
			>) I've been thinking about and prototyping related ideas for more than 13 years, and I think
			this iteration is sticking.
		</p>
		<p>Everything's a work in progress, but some basic integrations include:</p>
		<ul>
			<li>
				<External_Link href="https://github.com/ollama/ollama">Ollama</External_Link> runs AI models
				locally - this is just the first supported backend, more to come
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
				> for coordination with system access
			</li>
			<li>
				Planned:
				<ul>
					<li>
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
					<li>more, please send feedback/requests/help</li>
				</ul>
			</li>
		</ul>
		<p>
			Zzz is just one implementation of an increasingly common idea that combines web tech and AI
			with powerful open clients, and it has quirks personal to its author that I'm eager to smooth
			out. Your input would be appreciated to help make it work for you—see the <External_Link
				href="https://github.com/ryanatkn/zzz">code</External_Link
			>,
			<External_Link href="https://github.com/ryanatkn/zzz/issues">issues</External_Link>, and
			<External_Link href="https://github.com/ryanatkn/zzz/discussions">discussions</External_Link>,
			and find me on
			<External_Link href="https://bsky.app/profile/ryanatkn.com">Bluesky</External_Link>. I'll make
			a Discord if someone asks, and I'm planning to make a community site using Zzz at zzzbot.dev.
		</p>
	</section>
	<hr />
	<section>
		<h2 class="mb_lg">More details</h2>
		<ul>
			<li>Zzz is a noncommercial project and its only official domain is zzz.software</li>
			<li>
				it's open source, permissively licensed, and forking is encouraged - for less investment you
				can use it as a TypeScript/Svelte library (currently just npm)
			</li>
			<li>
				the Zzz name is community property, just don't falsely represent the official Zzz project or
				zzz.software
			</li>
			<li>
				I'm looking for <a href="https://www.ryanatkn.com/funding">funding</a> to make my continued full-time
				work on it sustainable
			</li>
		</ul>
	</section>
	<hr />
	<section>
		<h2 class="mb_lg">Into the future</h2>
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
