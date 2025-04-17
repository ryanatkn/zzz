<script lang="ts">
	import {base} from '$app/paths';
	import {GLYPH_SITE} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import Project_List from './_components/Project_List.svelte';
	import Project_Sidebar from './_components/Project_Sidebar.svelte';
	import {projects_store} from './sites.svelte.js';

	// TODO add to context or pass as prop
	const projects = $derived(projects_store.projects);

	let previewing = $state(false);
</script>

{#if previewing}
	<div class="flex">
		<Project_Sidebar {projects} />
		<main class="flex_1 p_md overflow_auto">
			{@render content()}
			<Project_List {projects} />
		</main>
	</div>
{:else}
	{@render content()}
{/if}

{#snippet content()}
	<h1><Glyph icon={GLYPH_SITE} /> sites</h1>

	<section class="width_md">
		<p>
			When it's ready, Zzz will let you both <a href="{base}/tabs">browse websites</a> and also create
			them, so Zzz is both a browser and editor for the read-write web, and it can be used as a desktop
			app to deploy and manage sites.
		</p>
		<p>
			Zzz tries to give us the maximum of the web's capabilities on all of our devices with minimal
			dependencies and optional third parties. A primary goal is to make managing websites routine
			and easy, because owning your web presence should be a cinch.
		</p>
		<p>
			Zzz doesn't try to be everything to everybody. That's what open standardized protocols are
			for! The goal here is to provide a streamlined extensible UX with one take on the web, with
			CMS and IDE features that leverage the rest of Zzz. Because it's the web, anything you make in
			Zzz can be used by other browsers and tools, and vice versa, like magic.
		</p>
		<p>
			Here's a very rough sketch of <button
				type="button"
				class="inline compact color_g"
				onclick={() => {
					previewing = !previewing;
				}}>what it could look like</button
			>.
		</p>
		<p>
			For developers, Zzz is also an npm library for TypeScript, Svelte, SvelteKit, and Vite that
			can be used to make websites and servers with your current workflows.
		</p>
		<p>More <a href="{base}/about">about</a> Zzz.</p>
	</section>
{/snippet}
