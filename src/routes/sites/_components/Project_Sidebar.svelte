<script lang="ts">
	import {page} from '$app/stores';
	import {GLYPH_SITE, GLYPH_PAGE, GLYPH_DOMAIN} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import type {Project} from '../sites.svelte.js';

	interface Props {
		projects: Array<Project>;
	}

	const {projects}: Props = $props();

	// Current path segments for determining active state
	const current_project_id = $derived($page.params.project_id);
	const current_page_id = $derived($page.params.page_id);
	const current_domain_id = $derived($page.params.domain_id);
	const current_path = $derived($page.url.pathname);

	// Project expanded states
	const expanded_projects: Record<string, boolean> = $state({});

	// Toggle project expansion
	const toggle_project = (project_id: string) => {
		expanded_projects[project_id] = !expanded_projects[project_id];
	};

	// Check if current path matches section
	const is_active_section = (path: string): boolean => {
		return current_path.includes(path);
	};
</script>

<nav class="project_sidebar">
	<div class="sidebar_header p_sm flex align_items_center justify_content_between">
		<h2 class="flex align_items_center gap_xs2">
			<Glyph icon={GLYPH_SITE} />
			<span>Sites</span>
		</h2>
	</div>

	<ul class="sidebar_nav">
		<li class:active={current_path === '/sites'}>
			<a href="/sites" class="nav_item p_xs">All Projects</a>
		</li>

		{#each projects as project (project.id)}
			<li class="project_item" class:active={project.id === current_project_id}>
				<!-- svelte-ignore a11y_click_events_have_key_events -->
				<!-- svelte-ignore a11y_no_static_element_interactions -->
				<div
					class="nav_item p_xs flex align_items_center justify_content_between"
					onclick={() => toggle_project(project.id)}
				>
					<span class="truncate">{project.name}</span>
					<span class="size_sm">{expanded_projects[project.id] ? '▾' : '▸'}</span>
				</div>

				{#if expanded_projects[project.id] || project.id === current_project_id}
					<ul class="sidebar_subnav">
						<li class:active={current_path === `/sites/${project.id}`}>
							<a href="/sites/{project.id}" class="nav_subitem p_xs">Overview</a>
						</li>

						<!-- Pages section -->
						<li class:active={is_active_section(`/sites/${project.id}/editor`)}>
							<div class="nav_subitem p_xs flex align_items_center gap_xs2">
								<Glyph icon={GLYPH_PAGE} size="var(--icon_size_xs)" />
								<span>Pages</span>
							</div>
							<ul class="sidebar_nested_nav">
								{#each project.pages as page (page.id)}
									<li class:active={page.id === current_page_id}>
										<a
											href="/sites/{project.id}/editor/{page.id}"
											class="nav_nested_item p_xs2 truncate"
											title={page.title}
										>
											{page.title}
										</a>
									</li>
								{/each}
								<li>
									<a href="/sites/{project.id}/editor/new" class="nav_nested_item p_xs2 color_5">
										+ New Page
									</a>
								</li>
							</ul>
						</li>

						<!-- Domains section -->
						<li class:active={is_active_section(`/sites/${project.id}/domains`)}>
							<div class="nav_subitem p_xs flex align_items_center gap_xs2">
								<Glyph icon={GLYPH_DOMAIN} size="var(--icon_size_xs)" />
								<span>Domains</span>
							</div>
							<ul class="sidebar_nested_nav">
								{#each project.domains as domain (domain.id)}
									<li class:active={domain.id === current_domain_id}>
										<a
											href="/sites/{project.id}/domains/{domain.id}"
											class="nav_nested_item p_xs2 truncate"
											title={domain.name}
										>
											{domain.name}
										</a>
									</li>
								{/each}
								<li>
									<a href="/sites/{project.id}/domains" class="nav_nested_item p_xs2 color_5">
										+ Add Domain
									</a>
								</li>
							</ul>
						</li>

						<!-- Settings section -->
						<li class:active={is_active_section(`/sites/${project.id}/settings`)}>
							<a href="/sites/{project.id}" class="nav_subitem p_xs">Settings</a>
						</li>
					</ul>
				{/if}
			</li>
		{/each}
	</ul>
</nav>

<style>
	.project_sidebar {
		width: 240px;
		background: var(--bg_1);
		border-right: 1px solid var(--border_color_1);
		display: flex;
		flex-direction: column;
		height: 100%;
		overflow-y: auto;
	}

	.sidebar_header {
		border-bottom: 1px solid var(--border_color_1);
	}

	.sidebar_nav {
		list-style: none;
		padding: 0;
		margin: 0;
	}

	.sidebar_subnav {
		list-style: none;
		padding: 0;
		margin: 0;
		padding-left: var(--size_sm);
	}

	.sidebar_nested_nav {
		list-style: none;
		padding: 0;
		margin: 0;
		padding-left: var(--size_md);
	}

	.nav_item {
		display: block;
		text-decoration: none;
		color: inherit;
		border-radius: var(--radius_xs);
	}

	.nav_subitem {
		display: block;
		text-decoration: none;
		color: inherit;
		border-radius: var(--radius_xs);
		font-size: 0.95em;
	}

	.nav_nested_item {
		display: block;
		text-decoration: none;
		color: inherit;
		border-radius: var(--radius_xs);
		font-size: 0.9em;
	}

	.project_item {
		margin-top: var(--size_xs);
	}

	.project_item.active > .nav_item {
		background-color: var(--color_a_1);
		font-weight: 500;
	}

	li.active > a {
		background-color: var(--color_a_1);
		font-weight: 500;
	}

	.nav_item:hover,
	.nav_subitem:hover,
	.nav_nested_item:hover {
		background-color: var(--bg_2);
	}

	.truncate {
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
</style>
