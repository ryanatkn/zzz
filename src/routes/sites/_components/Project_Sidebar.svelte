<script lang="ts">
	import {page} from '$app/state';

	import {GLYPH_PAGE, GLYPH_DOMAIN} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import Nav_Link from '$lib/Nav_Link.svelte';
	import {projects_context} from '../projects.svelte.js';

	// Get projects from context
	const projects = projects_context.get();

	// Current path segments for determining active state
	const current_project_id = $derived(page.params.project_id);
	const current_page_id = $derived(page.params.page_id);
	const current_domain_id = $derived(page.params.domain_id);
</script>

<nav class="project_sidebar">
	<div class="sidebar_nav">
		<Nav_Link href="/sites" attrs={{class: 'sidebar_link'}}>projects</Nav_Link>

		{#each projects.projects as project (project.id)}
			<div class="project_item">
				<!-- svelte-ignore a11y_click_events_have_key_events -->
				<!-- svelte-ignore a11y_no_static_element_interactions -->
				<div
					class="project_header sidebar_link"
					class:selected={project.id === current_project_id}
					onclick={() => projects.toggle_project_expanded(project.id)}
				>
					<span class="truncate">{project.name}</span>
					<span class="size_sm">{projects.expanded_projects[project.id] ? '▾' : '▸'}</span>
				</div>

				{#if projects.expanded_projects[project.id] || project.id === current_project_id}
					<div class="sidebar_subnav">
						<Nav_Link href="/sites/{project.id}" attrs={{class: 'sidebar_sublink'}}>
							Overview
						</Nav_Link>

						<!-- Pages section -->
						<div class="nav_section">
							<div class="sidebar_sublink nav_section_header">
								<Glyph icon={GLYPH_PAGE} size="var(--icon_size_xs)" />
								<span>Pages</span>
							</div>
							<div class="sidebar_nested_nav">
								{#each project.pages as page (page.id)}
									<Nav_Link
										href="/sites/{project.id}/editor/{page.id}"
										selected={page.id === current_page_id}
										attrs={{class: 'sidebar_nested_link truncate', title: page.title}}
									>
										{page.title}
									</Nav_Link>
								{/each}
								<Nav_Link
									href="/sites/{project.id}/editor/new"
									attrs={{class: 'sidebar_nested_link color_5'}}
								>
									+ new page
								</Nav_Link>
							</div>
						</div>

						<!-- Domains section -->
						<div class="nav_section">
							<div class="sidebar_sublink nav_section_header">
								<Glyph icon={GLYPH_DOMAIN} size="var(--icon_size_xs)" />
								<span>Domains</span>
							</div>
							<div class="sidebar_nested_nav">
								{#each project.domains as domain (domain.id)}
									<Nav_Link
										href="/sites/{project.id}/domains/{domain.id}"
										selected={domain.id === current_domain_id}
										attrs={{class: 'sidebar_nested_link truncate', title: domain.name}}
									>
										{domain.name}
									</Nav_Link>
								{/each}
								<Nav_Link
									href="/sites/{project.id}/domains"
									attrs={{class: 'sidebar_nested_link color_5'}}
								>
									+ add domain
								</Nav_Link>
							</div>
						</div>

						<!-- Settings section -->
						<Nav_Link href="/sites/{project.id}" attrs={{class: 'sidebar_sublink'}}>
							settings
						</Nav_Link>
					</div>
				{/if}
			</div>
		{/each}
	</div>
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

	.sidebar_nav {
		display: flex;
		flex-direction: column;
		padding: var(--space_xs);
	}

	.sidebar_subnav {
		display: flex;
		flex-direction: column;
		padding-left: var(--space_sm);
	}

	.sidebar_nested_nav {
		display: flex;
		flex-direction: column;
		padding-left: var(--space_md);
	}

	.project_item {
		margin-top: var(--space_xs);
	}

	.project_header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: var(--space_xs2) var(--space_sm);
		cursor: pointer;
	}

	.project_header.selected {
		border-color: var(--border_color_a);
		color: var(--color_a_6);
	}

	.nav_section_header {
		display: flex;
		align-items: center;
		gap: var(--space_xs2);
		cursor: default;
		font-weight: 500;
	}

	.sidebar_link {
		padding: var(--space_xs2) var(--space_sm);
		border: var(--border_width_2) var(--border_style) transparent;
		border-radius: var(--radius_xs);
		color: var(--text_color_2);
		font-weight: 600;
	}

	.sidebar_sublink {
		padding: var(--space_xs2) var(--space_sm);
		border: var(--border_width_2) var(--border_style) transparent;
		border-radius: var(--radius_xs);
		color: var(--text_color_2);
		font-size: 0.95em;
	}

	.project_sidebar :global(.sidebar_nested_link) {
		padding: var(--space_xs2) var(--space_xs);
		border: var(--border_width_2) var(--border_style) transparent;
		border-radius: var(--radius_xs);
		color: var(--text_color_2);
		font-size: 0.9em;
	}

	.nav_section {
		margin: var(--space_xs) 0;
	}

	.truncate {
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
</style>
